import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/api/socket_service.dart';
import 'data/ai_repository.dart';
import 'domain/chat_message.dart';
import 'presentation/message_bubble.dart';

class AiChatScreen extends StatefulWidget {
  final String? conversationId;
  // "Fotoğraf Gönder" kısayolundan girildiğinde ekran açılır açılmaz
  // fotoğraf seçiciyi otomatik başlatsın diye.
  final bool autoOpenCamera;
  // Ana Sayfa'nın üst kutusundan doğrudan soru/fotoğraf ile gelindiğinde
  // ekran açılır açılmaz otomatik gönderim yapılsın diye.
  final String? initialQuestion;
  final File? initialImage;

  const AiChatScreen({
    super.key,
    this.conversationId,
    this.autoOpenCamera = false,
    this.initialQuestion,
    this.initialImage,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _repository = AiRepository();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = stt.SpeechToText();
  final _socket = SocketService();

  StreamSubscription<Map<String, dynamic>>? _messageSub;
  String? _conversationId;
  List<ChatMessage> _messages = [];
  // AI Teknik Soru Hafızası — hangi mesaj ID'lerinin geçmiş bir kayıttan
  // geldiğini tutar, "Bu soru daha önce yanıtlandı" göstergesi için.
  final Set<String> _fromMemoryMessageIds = {};
  bool _loading = true;
  bool _sending = false;
  bool _listening = false;
  // Seçilen/çekilen fotoğraf, gönderilmeden önce burada "bekler" —
  // kullanıcı fotoğrafı gördükten sonra soru yazıp öyle gönderebilir.
  File? _pendingImage;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _loadHistory();
    _connectRealtime();
    if (widget.autoOpenCamera) {
      // Ekran ilk çizildikten hemen sonra fotoğraf seçiciyi aç — sadece
      // SEÇER, otomatik göndermez; kullanıcı önce fotoğrafı görüp isterse
      // soru yazabilsin diye.
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickPhoto());
    } else if (widget.initialQuestion != null || widget.initialImage != null) {
      // Ana Sayfa'nın üst kutusundan soru/fotoğraf ile geldiyse, kullanıcı
      // zaten "gönder"e bastığı için burada bekletmeden hemen gönderiyoruz.
      _inputController.text = widget.initialQuestion ?? '';
      _pendingImage = widget.initialImage;
      WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    }
  }

  Future<void> _connectRealtime() async {
    await _socket.connect();
    if (_conversationId != null) _socket.joinConversation(_conversationId!);
    _messageSub = _socket.onMessage.listen((data) {
      // Backend'in gönderdiği mesaj bu konuşmaya ait mi kontrol edelim.
      if (data['conversationId'] != null && data['conversationId'] != _conversationId) return;
      final incoming = ChatMessage.fromJson(data);
      if (_messages.any((m) => m.id == incoming.id)) return; // zaten optimistic olarak eklenmiş olabilir
      setState(() => _messages = [..._messages, incoming]);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Kullanıcı isteği: "cevap doğruysa mühendislik hafızası çalışsın" ve
  /// "doğrulama sürekli kalmalı" — herhangi bir bayi bu cevabı "doğru"
  /// olarak işaretleyebilir; bu artık backend'de kalıcı olarak saklanıyor
  /// (uygulama kapatılıp açılsa, konuşma yeniden yüklense bile kalır).
  Future<void> _verifyAnswer(int index) async {
    final msg = _messages[index];
    if (msg.memoryId == null || msg.memoryIsVerified) return;
    setState(() => _messages[index] = msg.copyWith(memoryIsVerified: true));
    try {
      await _repository.verifyMemory(msg.memoryId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cevap doğrulandı — bundan sonra bu soru için AI daha hızlı cevap verecek.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages[index] = msg.copyWith(memoryIsVerified: false));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğrulama başarısız oldu, tekrar deneyin.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    if (_conversationId != null) _socket.leaveConversation(_conversationId!);
    _messageSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    // Kullanıcı isteği: "aı teknik asistana basınca içine sürekli
    // yazabileyim, her yeni soruda kart açmasın" — bu ekran artık
    // (AI sekmesinin kökünden, conversationId verilmeden) açıldığında,
    // kullanıcının ZATEN var olan tek sürekli sohbetini kendisi bulup
    // yüklüyor. Ayrı bir "önizleme kartı" ekranına gerek kalmıyor.
    if (_conversationId == null) {
      try {
        final conversations = await _repository.listConversations();
        if (conversations.isNotEmpty) {
          _conversationId = conversations.first['id'] as String;
          if (_conversationId != null) _socket.joinConversation(_conversationId!);
        }
      } catch (_) {
        // Sessizce geç — kullanıcı yine de yeni bir soru sorabilir.
      }
    }
    if (_conversationId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final messages = await _repository.listMessages(_conversationId!);
      setState(() {
        _messages = messages.reversed.toList(); // API en yeniden en eskiye döner
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  /// Kullanıcı isteği: "yeni sohbet dediğimde ayrı bir kart açmalı, eski
  /// sohbet eski kartının içinde, yeni sohbet yeni kartının içinde
  /// kalmalı" — artık backend'de GERÇEKTEN yeni, ayrı bir konuşma
  /// oluşturuluyor. Eski konuşma hiç değişmeden kendi kaydında kalıyor,
  /// bu ekran sadece o yeni (boş) konuşmaya geçiyor.
  Future<void> _startNewConversation() async {
    try {
      final oldConversationId = _conversationId;
      if (oldConversationId != null) _socket.leaveConversation(oldConversationId);
      final newId = await _repository.createNewConversation();
      if (!mounted) return;
      setState(() {
        _conversationId = newId;
        _messages = [];
      });
      _socket.joinConversation(newId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni bir sohbet başlattınız.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni sohbet başlatılamadı, tekrar deneyin.'), backgroundColor: Colors.red),
      );
    }
  }

  /// Kullanıcı isteği: eski sohbetlere geri dönebilmek için basit bir
  /// geçmiş listesi — alttan açılan bir pencerede tüm AI konuşmalarını
  /// gösterir, birine dokununca o konuşmaya geçilir.
  Future<void> _showHistory() async {
    List<dynamic> conversations;
    try {
      conversations = await _repository.listConversations();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçmiş yüklenemedi.'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!mounted) return;
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sohbet Geçmişiniz', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Expanded(
              child: conversations.isEmpty
                  ? const Center(child: Text('Henüz bir sohbetiniz yok.'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final c = conversations[index];
                        final msgs = (c['messages'] as List);
                        final lastMsg = msgs.isNotEmpty ? msgs[0]['content'] as String? : null;
                        final isActive = c['id'] == _conversationId;
                        return ListTile(
                          leading: Icon(Icons.chat_bubble_outline, color: isActive ? Colors.green : Colors.grey),
                          title: Text(
                            lastMsg ?? 'Yeni sohbet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: isActive ? FontWeight.w800 : FontWeight.w500),
                          ),
                          trailing: isActive ? const Text('Şu an burada', style: TextStyle(fontSize: 11, color: Colors.green)) : null,
                          onTap: () => Navigator.pop(sheetContext, c['id'] as String),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
    if (selectedId != null && selectedId != _conversationId) {
      if (_conversationId != null) _socket.leaveConversation(_conversationId!);
      setState(() {
        _conversationId = selectedId;
        _loading = true;
      });
      _socket.joinConversation(selectedId);
      final messages = await _repository.listMessages(selectedId);
      if (!mounted) return;
      setState(() {
        _messages = messages.reversed.toList();
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  /// Tek, birleşik gönderme fonksiyonu — bekleyen bir fotoğraf varsa
  /// fotoğraf+soru birlikte, yoksa sadece metin gönderilir. Fotoğrafsız
  /// da, fotoğrafla da soru sorulabilir.
  Future<void> _send() async {
    final question = _inputController.text.trim();
    if (question.isEmpty && _pendingImage == null) return;
    if (_sending) return;
    final imageToSend = _pendingImage;
    _inputController.clear();

    // ÖNEMLİ DÜZELTME: Kullanıcı isteği — "her sorduğum soru anlık
    // ekranda görünmeli." Önceden sadece AI'ın cevabı ekleniyordu,
    // kullanıcının kendi sorusu hiç eklenmiyordu (Socket.IO'nun bunu
    // yakalaması zamanlamaya bağlıydı, güvenilir değildi). Artık soru,
    // gönderilir gönderilmez YEREL olarak ekleniyor — sunucudan cevap
    // beklemeye gerek yok.
    final tempUserMessage = ChatMessage(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      content: question,
      senderType: SenderType.user,
      confidence: Confidence.none,
      citations: const [],
      createdAt: DateTime.now(),
    );

    setState(() {
      _sending = true;
      _pendingImage = null;
      _messages = [..._messages, tempUserMessage];
    });
    _scrollToBottom();

    try {
      final wasNew = _conversationId == null;
      final result = imageToSend != null
          ? await _repository.askWithImage(image: imageToSend, question: question, conversationId: _conversationId)
          : await _repository.ask(question: question, conversationId: _conversationId);
      _conversationId = result.conversationId;
      if (wasNew) _socket.joinConversation(_conversationId!);
      // AI cevabı Socket.IO üzerinden de yayınlanıyor; aynı mesajın iki kez
      // eklenmesini önlemek için id kontrolü yapıyoruz.
      if (!_messages.any((m) => m.id == result.message.id)) {
        if (result.fromMemory) _fromMemoryMessageIds.add(result.message.id);
        setState(() => _messages = [..._messages, result.message]);
      }
      _scrollToBottom();
    } catch (e) {
      // ÖNEMLİ DÜZELTME: Aynı Ana Sayfa'daki sessiz başarısızlık hatası
      // burada da vardı — özellikle günlük soru limiti dolduğunda
      // kullanıcı hiçbir şey görmüyordu. Metin de kaybolmuyor, tekrar
      // yazmasına gerek yok.
      if (!mounted) return;
      _inputController.text = question;
      // Gönderim başarısız oldu — yerel olarak eklediğimiz geçici soru
      // balonunu da geri alalım, yanıltıcı olmasın.
      setState(() => _messages.removeWhere((m) => m.id == tempUserMessage.id));
      String message = 'Sorunuz gönderilemedi, tekrar deneyin.';
      if (e is DioException) {
        final serverMessage = e.response?.data?['message'];
        if (serverMessage is String && serverMessage.isNotEmpty) {
          message = serverMessage;
        } else if (e.response?.statusCode == 500) {
          message = 'Sunucu şu an cevap veremiyor. Lütfen daha sonra tekrar deneyin.';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Sadece fotoğraf SEÇER/ÇEKER — göndermez. Kullanıcı fotoğrafı önizleme
  /// alanında görüp isterse bir soru yazıp öyle gönderebilir.
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera ile çek'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden Seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() => _pendingImage = File(picked.path));
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize();
    if (!available) return;
    setState(() => _listening = true);
    _speech.listen(
      localeId: 'tr_TR',
      onResult: (result) {
        setState(() => _inputController.text = result.recognizedWords);
        if (result.finalResult) setState(() => _listening = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Teknik Asistan'),
        // ÖNEMLİ DÜZELTME: Bu ekran, alt menüdeki "AI" sekmesinin kök
        // ekranına (AiAssistantScreen) otomatik yönlendirmeyle
        // (pushReplacement) açılıyor — bu, geri gidilecek bir sayfa
        // bırakmadığı için geri oku hiç çıkmıyordu. Artık geri
        // gidilebiliyorsa normal geri davranışı, gidilemiyorsa (bu
        // ekran sekmenin kökündeyse) doğrudan Ana Sayfa'ya dönen açık
        // bir buton gösteriliyor.
        leading: Navigator.of(context).canPop()
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop())
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
        actions: [
          // Kullanıcı isteği: eski sohbetlere geri dönebilmek için.
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Sohbet Geçmişi',
            onPressed: _showHistory,
          ),
          // Kullanıcı isteği: "yeni sohbet dediğimde ayrı bir kart
          // açmalı" — gerçekten yeni, ayrı bir konuşma başlatır.
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Yeni Sohbet',
            onPressed: _startNewConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    // Kullanıcı isteği: "aı cevap vermeye başlarken entpa aı
                    // düşünüyor demeli" — gönderim sürerken listenin en
                    // sonuna bir "düşünüyor" göstergesi ekleniyor.
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _ThinkingBubble();
                      }
                      return MessageBubble(
                        message: _messages[index],
                        onFavorite: () => _repository.toggleFavorite(_messages[index].id),
                        fromMemory: _fromMemoryMessageIds.contains(_messages[index].id),
                        canVerify: _messages[index].memoryId != null,
                        isVerified: _messages[index].memoryIsVerified,
                        onVerify: () => _verifyAnswer(index),
                      );
                    },
                  ),
          ),
          // Bekleyen fotoğraf önizlemesi — gönderilmeden önce kullanıcı
          // fotoğrafı görüp isterse kaldırabilir.
          if (_pendingImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_pendingImage!, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Fotoğraf eklendi — isterseniz bir soru yazıp gönderin.', style: TextStyle(fontSize: 12.5)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _pendingImage = null),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined),
                    onPressed: _sending ? null : _pickPhoto,
                    tooltip: 'Fotoğraf çek / galeriden seç',
                  ),
                  IconButton(
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none_outlined, color: _listening ? Colors.red : null),
                    onPressed: _toggleListening,
                    tooltip: 'Sesli soru',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(hintText: 'Mesajınızı yazın...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// AI cevap üretirken gösterilen "düşünüyor" balonu.
class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'ENTPA AI düşünüyor...',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
