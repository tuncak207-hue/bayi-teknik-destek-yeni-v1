import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/api/socket_service.dart';
import '../../core/auth/current_user.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';
import '../../core/events/messages_badge_bus.dart';

class ChatThreadScreen extends StatefulWidget {
  final String conversationId;
  // Genel Sohbet ekranı bu widget'ı yeniden kullanıyor; farklı bir başlık
  // ve AppBar'a ekstra bir buton (Bayi Rehberi'ne gitmek için) eklemesi
  // gerekiyor — bu yüzden opsiyonel olarak dışarıdan verilebiliyor.
  final String title;
  final List<Widget> extraAppBarActions;

  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    this.title = 'Sohbet',
    this.extraAppBarActions = const [],
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final Dio _dio = ApiClient().dio;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _socket = SocketService();

  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<String>? _typingSub;
  List<dynamic> _messages = [];
  bool _loading = true;

  /// userId -> görünen ad (örn. "Ayşe Demir"). Grup sohbetlerinde birden
  /// fazla kişi olabileceği için bir harita olarak tutuyoruz.
  final Map<String, String> _participantNames = {};
  // "Gönderildi/okundu" tikleri için — karşı tarafın son okuma zamanı.
  final Map<String, DateTime?> _participantLastRead = {};
  String? _conversationType;
  String? _myUserId;

  // "Yazıyor..." göstergesi: önceden sendTyping() çağrılıyordu ama karşı
  // tarafın ekranında hiçbir yerde gösterilmiyordu — tek yönlü, ölü bir
  // özellikti. Şimdi karşı taraftan gelen sinyali dinleyip kısa süreliğine
  // bir "X yazıyor..." çubuğu gösteriyoruz.
  String? _typingUserId;
  Timer? _typingClearTimer;

  // Yanıt verilecek mesaj (varsa) — "alıntı" önizlemesi burada tutulur.
  Map<String, dynamic>? _replyingTo;

  // Sohbet içi arama: aktifken üstte bir arama kutusu çıkar, sonuçlar
  // backend'den (tüm geçmişte, sayfalama sınırı olmadan) çekilir.
  bool _searchMode = false;
  final _searchController = TextEditingController();
  List<dynamic>? _searchResults;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _myUserId = CurrentUser().id;
    _loadParticipants();
    _load();
    _connectRealtime();
    // Bu sohbete hangi yoldan girilirse girilsin (bildirime dokunma,
    // derin bağlantı vb.) okunmamış mesaj işaretini temizle — sadece
    // Mesajlar listesinden tıklanınca değil.
    _dio.post('/notifications/mark-conversation-read/${widget.conversationId}');
    // Alt menüdeki Mesajlar rozetinin de senkron kalması için sinyal
    // gönderiyoruz — RootShell bunu dinleyip gerçek sayıyı sunucudan
    // yeniden çekiyor.
    MessagesBadgeBus.bump();
    // "Okundu" tiklerinin, karşı taraf mesajı okuduğunda makul bir sürede
    // güncellenmesi için periyodik olarak katılımcı bilgisini tazeliyoruz
    // (bu ekran açıkken).
    _readReceiptTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadParticipants());
  }

  Timer? _readReceiptTimer;

  Future<void> _loadParticipants() async {
    try {
      final res = await _dio.get('/chat/conversations');
      final conversation = (res.data as List).firstWhere(
        (c) => c['id'] == widget.conversationId,
        orElse: () => null,
      );
      if (conversation == null) return;
      final participants = conversation['participants'] as List? ?? [];
      final names = <String, String>{};
      final lastReads = <String, DateTime?>{};
      for (final p in participants) {
        final user = p['user'];
        if (user != null) {
          names[p['userId']] = '${user['firstName']} ${user['lastName']}';
        }
        lastReads[p['userId']] = DateTime.tryParse(p['lastReadAt'] ?? '');
      }
      if (mounted) {
        setState(() {
          _participantNames.addAll(names);
          _participantLastRead
            ..clear()
            ..addAll(lastReads);
          _conversationType = conversation['type'];
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('[chat] Katılımcı bilgisi alınamadı: $e');
    }
  }

  /// Gönderdiğim bir mesajın "okundu" sayılıp sayılmayacağını, karşı
  /// tarafın son okuma zamanının bu mesajdan sonra olup olmadığına göre
  /// belirler — DIRECT (özel) sohbetlerde anlamlı, gruplarda göstermiyoruz.
  bool _isReadByOther(DateTime messageCreatedAt) {
    if (_conversationType != 'DIRECT') return false;
    for (final entry in _participantLastRead.entries) {
      if (entry.key == _myUserId) continue;
      final lastRead = entry.value;
      if (lastRead != null && !lastRead.isBefore(messageCreatedAt)) return true;
    }
    return false;
  }

  String _formatMessageTime(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (isToday) return time;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} $time';
  }

  Future<void> _connectRealtime() async {
    await _socket.connect();
    _socket.joinConversation(widget.conversationId);
    _messageSub = _socket.onMessage.listen((data) {
      if (data['conversationId'] != widget.conversationId) return;
      if (_messages.any((m) => m['id'] == data['id'])) return; // optimistic olarak zaten eklenmişse tekrar ekleme
      setState(() => _messages = [..._messages, data]);
      _scrollToBottom();
      // Karşı taraf mesaj yazdıysa muhtemelen sohbeti de görüyordur —
      // okundu durumunu daha hızlı yansıtmak için hemen tazeleyelim.
      _loadParticipants();
    });
    _typingSub = _socket.onTyping.listen((userId) {
      if (userId == _myUserId) return; // kendi yazma sinyalimizi göstermeyelim
      _typingClearTimer?.cancel();
      setState(() => _typingUserId = userId);
      // Karşı taraf yazmayı bırakınca sinyal tekrar gelmeyeceği için,
      // 3 saniye sonra göstergeyi otomatik kaldırıyoruz.
      _typingClearTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _typingUserId = null);
      });
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

  @override
  void dispose() {
    _socket.leaveConversation(widget.conversationId);
    _messageSub?.cancel();
    _typingSub?.cancel();
    _typingClearTimer?.cancel();
    _readReceiptTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await _dio.get('/chat/conversations/${widget.conversationId}/messages');
    setState(() {
      _messages = (res.data as List).reversed.toList();
      _loading = false;
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;
    _inputController.clear();
    final replyToId = _replyingTo?['id'];
    setState(() => _replyingTo = null);
    try {
      final res = await _dio.post(
        '/chat/conversations/${widget.conversationId}/messages',
        data: {'content': content, if (replyToId != null) 'replyToId': replyToId},
      );
      if (!_messages.any((m) => m['id'] == res.data['id'])) {
        setState(() => _messages = [..._messages, res.data]);
      }
      _scrollToBottom();
    } on DioException catch (e) {
      // Admin tarafından süreli konuşma yasağı verilmişse backend 403 ile
      // net bir mesaj döner ("Kalan süre: X saat") — bunu kullanıcıya
      // olduğu gibi gösteriyoruz. Metni geri koyuyoruz ki kaybolmasın.
      _inputController.text = content;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message'] ?? 'Mesaj gönderilemedi.')),
        );
      }
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await _dio.get(
        '/chat/conversations/${widget.conversationId}/messages/search',
        queryParameters: {'q': query},
      );
      if (mounted) setState(() => _searchResults = res.data);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  static const _kQuickReactions = ['👍', '❤️', '😂', '😮', '🙏'];

  /// Aynı emoji ile birden fazla tepki varsa ("👍👍👍" yerine "👍 3") sayarak gruplar.
  Map<String, int> _groupedReactions(List reactions) {
    final map = <String, int>{};
    for (final r in reactions) {
      final emoji = r['emoji'] as String;
      map[emoji] = (map[emoji] ?? 0) + 1;
    }
    return map;
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    await _dio.post('/chat/messages/$messageId/react', data: {'emoji': emoji});
    // Sunucudan gelecek gerçek durumu beklemeden, listeyi yeniden çekip
    // tepkilerin güncel hâlini gösteriyoruz — basit ve güvenilir.
    _load();
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mesajı Sil'),
        content: const Text('Bu mesajı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil', style: TextStyle(color: AppColors.navy)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dio.delete('/chat/messages/$messageId');
      setState(() => _messages.removeWhere((m) => m['id'] == messageId));
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message'] ?? 'Mesaj silinemedi.')),
        );
      }
    }
  }

  /// Karşı tarafın gönderdiği bir mesajı sadece kendi görünümümden
  /// kaldırır — karşı tarafta silinmez. Kullanıcı isteği: "gelen
  /// mesajları... silebiliyor olmam gerekirken silemiyorum."
  Future<void> _hideMessageForMe(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mesajı Sil'),
        content: const Text('Bu mesaj sadece sizin sohbetinizden kaldırılacak, karşı tarafta silinmeyecek. Onaylıyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil', style: TextStyle(color: AppColors.navy)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dio.post('/chat/messages/$messageId/hide-for-me');
      setState(() => _messages.removeWhere((m) => m['id'] == messageId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesaj kaldırılamadı, tekrar deneyin.')));
      }
    }
  }

  /// Mesajlar gönderildikten sonra sadece kısa bir süre (backend'de 15
  /// dakika olarak tanımlı) düzenlenebilir/silinebilir — bu, WhatsApp/Slack
  /// gibi uygulamalardaki "kısa süreli geri alma" mantığıyla aynı.
  Future<void> _editMessage(dynamic message) async {
    final controller = TextEditingController(text: message['content']);
    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mesajı Düzenle'),
        content: TextField(controller: controller, maxLines: 4, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (newContent == null || newContent.isEmpty || newContent == message['content']) return;
    try {
      final res = await _dio.patch('/chat/messages/${message['id']}', data: {'content': newContent});
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == message['id']);
        if (index != -1) _messages[index] = res.data;
      });
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message'] ?? 'Mesaj düzenlenemedi.')),
        );
      }
    }
  }

  void _showMessageActions(dynamic message) {
    final isMine = _isMine(message);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _kQuickReactions
                    .map((emoji) => InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.pop(context);
                            _toggleReaction(message['id'], emoji);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(emoji, style: const TextStyle(fontSize: 26)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Yanıtla'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = message);
              },
            ),
            if (isMine) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Düzenle'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.navy),
                title: const Text('Sil', style: TextStyle(color: AppColors.navy)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message['id']);
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.navy),
                title: const Text('Sil (sadece benden)', style: TextStyle(color: AppColors.navy)),
                onTap: () {
                  Navigator.pop(context);
                  _hideMessageForMe(message['id']);
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _sendingAttachment = false;

  /// Fotoğraf ekleme: cihazın kamerası veya galerisinden bir görsel seçip
  /// backend'e yükler, dönen mesajı sohbete ekler. (Genel dosya seçimi
  /// için `file_picker` paketi, daha önce derleme sorunlarına yol açtığı
  /// için bilinçli olarak eklenmedi — bkz. proje notları.)
  Future<void> _pickAndSendAttachment() async {
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
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    setState(() => _sendingAttachment = true);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(picked.path, filename: picked.name),
      });
      final res = await _dio.post('/chat/conversations/${widget.conversationId}/attachments', data: formData);
      if (!_messages.any((m) => m['id'] == res.data['id'])) {
        setState(() => _messages = [..._messages, res.data]);
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya gönderilemedi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingAttachment = false);
    }
  }

  bool _isMine(dynamic message) {
    final senderId = message['senderId'];
    if (senderId == null || _myUserId == null) return false;
    return senderId == _myUserId;
  }

  String _senderLabel(dynamic message) {
    final senderId = message['senderId'];
    if (senderId == null) return '';
    if (senderId == _myUserId) return 'Sen';
    return _participantNames[senderId] ?? 'Bayi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppPageHeader(
        title: widget.title,
        actions: [
          ...widget.extraAppBarActions,
          IconButton(
            icon: Icon(_searchMode ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searchMode = !_searchMode;
              if (!_searchMode) {
                _searchController.clear();
                _searchResults = null;
              }
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchMode)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Bu sohbette ara...',
                  prefixIcon: _searching
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                      : const Icon(Icons.search),
                ),
                onChanged: _search,
              ),
            ),
          if (_searchMode && _searchResults != null)
            Expanded(
              child: _searchResults!.isEmpty
                  ? Center(child: Text('Sonuç bulunamadı.', style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      itemCount: _searchResults!.length,
                      itemBuilder: (context, index) {
                        final m = _searchResults![index];
                        return ListTile(
                          leading: const Icon(Icons.chat_bubble_outline, size: 18),
                          title: Text(m['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(_senderLabel(m)),
                          onTap: () {
                            // Basit bir sonuç görünümü — mesaja atlamak yerine
                            // arama modundan çıkıp normal akışa dönüyoruz.
                            setState(() {
                              _searchMode = false;
                              _searchResults = null;
                            });
                          },
                        );
                      },
                    ),
            )
          else
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isMine = _isMine(m);
                      final replyTo = m['replyTo'];
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _showMessageActions(m),
                          child: Column(
                            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  _senderLabel(m),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 2, bottom: 4),
                                padding: const EdgeInsets.all(12),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                decoration: BoxDecoration(
                                  color: isMine ? AppColors.brand : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (replyTo != null)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: (isMine ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border(
                                            left: BorderSide(color: isMine ? Colors.white : AppColors.navy, width: 2.5),
                                          ),
                                        ),
                                        child: Text(
                                          replyTo['content'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isMine ? Colors.white.withValues(alpha: 0.85) : Colors.black54,
                                          ),
                                        ),
                                      ),
                                    if (m['attachmentUrl'] != null && m['attachmentType'] == 'image')
                                      _AttachmentImage(storageKey: m['attachmentUrl'])
                                    else if (m['attachmentUrl'] != null)
                                      // Önceden PDF/dosya ekleri sadece düz metin (dosya adı) olarak
                                      // görünüyordu, tıklanamıyordu. Artık gerçek bir dosya "çipi".
                                      _AttachmentFileChip(
                                        storageKey: m['attachmentUrl'],
                                        fileName: m['content'] ?? 'Dosya',
                                        isMine: isMine,
                                      )
                                    else
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: m['content'] ?? '',
                                              style: TextStyle(color: isMine ? Colors.white : Colors.black87),
                                            ),
                                            if (m['editedAt'] != null)
                                              TextSpan(
                                                text: '  (düzenlendi)',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontStyle: FontStyle.italic,
                                                  color: (isMine ? Colors.white : Colors.black87).withValues(alpha: 0.6),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    // Tarih/saat + (gönderen bendeysem) okundu tiki —
                                    // önceden mesajlarda hiç zaman gösterilmiyordu.
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatMessageTime(m['createdAt']),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: (isMine ? Colors.white : Colors.black87).withValues(alpha: 0.55),
                                            ),
                                          ),
                                          if (isMine) ...[
                                            const SizedBox(width: 3),
                                            Builder(builder: (context) {
                                              final createdAt = DateTime.tryParse(m['createdAt'] ?? '');
                                              final read = createdAt != null && _isReadByOther(createdAt);
                                              return Icon(
                                                read ? Icons.done_all : Icons.done,
                                                size: 13,
                                                color: read ? Colors.lightBlueAccent : Colors.white.withValues(alpha: 0.6),
                                              );
                                            }),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if ((m['reactions'] as List?)?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Wrap(
                                    spacing: 4,
                                    children: _groupedReactions(m['reactions'] as List)
                                        .entries
                                        .map((e) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: AppColors.divider),
                                              ),
                                              child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 11)),
                                            ))
                                        .toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_typingUserId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_participantNames[_typingUserId] ?? 'Karşı taraf'} yazıyor...',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  Container(width: 3, height: 32, color: AppColors.navy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Yanıtlanıyor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.navy)),
                        Text(
                          _replyingTo!['content'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _replyingTo = null),
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
                    icon: _sendingAttachment
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.attach_file),
                    onPressed: _sendingAttachment ? null : _pickAndSendAttachment,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(hintText: 'Mesaj yazın...'),
                      onChanged: (_) => _socket.sendTyping(widget.conversationId),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ek olarak gönderilen bir görseli, imzalı URL alıp gösteren widget.
class _AttachmentImage extends StatelessWidget {
  final String storageKey;
  const _AttachmentImage({required this.storageKey});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Response>(
      future: ApiClient().dio.get('/chat/attachments/signed-url', queryParameters: {'key': storageKey}),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 160,
            height: 160,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox(width: 160, height: 80, child: Center(child: Icon(Icons.broken_image_outlined)));
        }
        final url = snapshot.data!.data as String;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              width: 160,
              height: 80,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        );
      },
    );
  }
}

/// PDF/dosya ekleri için tıklanabilir "çip" — önceden bu türdeki ekler
/// sadece dosya adı olarak düz metin gösteriliyor, hiç açılamıyordu.
/// Tıklanınca imzalı URL alınır, cihaza indirilir ve sistem uygulamasıyla açılır.
class _AttachmentFileChip extends StatefulWidget {
  final String storageKey;
  final String fileName;
  final bool isMine;

  const _AttachmentFileChip({required this.storageKey, required this.fileName, required this.isMine});

  @override
  State<_AttachmentFileChip> createState() => _AttachmentFileChipState();
}

class _AttachmentFileChipState extends State<_AttachmentFileChip> {
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    try {
      final signed = await ApiClient().dio.get('/chat/attachments/signed-url', queryParameters: {'key': widget.storageKey});
      final url = signed.data as String;
      final tempDir = await getTemporaryDirectory();
      final safeName = widget.fileName.replaceAll(RegExp(r'[^\w\s.-]'), '');
      final path = '${tempDir.path}/$safeName';
      await Dio().download(url, path); // Authorization başlığı taşımayan çıplak istemci — R2 imzasıyla çakışmasın diye
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya açılamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMine ? Colors.white : AppColors.navy;
    return InkWell(
      onTap: _opening ? null : _open,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _opening
              ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Icon(Icons.insert_drive_file_outlined, color: color, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              widget.fileName,
              style: TextStyle(color: color, decoration: TextDecoration.underline),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
