import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/widgets/design_system.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'data/ai_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';

/// Kullanıcı isteği: "AI Teknik Asistan kendi sayfası olacak, sohbet
/// ayrı." Önceden bu ekran, mevcut bir sohbet varsa otomatik olarak
/// (pushReplacement ile) sohbet ekranına yönlendiriyordu — bu, "2 sayfa
/// açılıyor gibi" hissettiriyordu. Artık bu ekran KENDİ BAŞINA duran,
/// bağımsız bir sayfa: devam eden sohbet varsa bir ÖNİZLEME kartı olarak
/// gösteriliyor, sohbetin kendisine sadece o karta ya da yeni bir soru
/// gönderince GİRİLİYOR — otomatik yönlendirme yok.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _repository = AiRepository();
  final _questionController = TextEditingController();
  Map<String, dynamic>? _activeConversation;
  bool _loading = true;
  bool _submitting = false;
  // ÖNEMLİ DÜZELTME: "key reservation contains key" hatası — kullanıcı
  // önizleme kartına art arda hızlı basınca, aynı sohbet rotası iki kez
  // üst üste açılmaya çalışılıyor, bu da Flutter'ın aynı GlobalKey'i iki
  // kez kullanma hatasına yol açıyordu. Bu bayrak, gezinme sürerken
  // ikinci bir tıklamayı engelliyor.
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final conversations = await _repository.listConversations();
      if (!mounted) return;
      setState(() {
        _activeConversation = conversations.isNotEmpty ? conversations.first as Map<String, dynamic> : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startNewQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _submitting || _navigating) return;
    setState(() => _submitting = true);
    try {
      final result = await _repository.ask(question: question);
      if (!mounted) return;
      _questionController.clear();
      _navigating = true;
      await context.push('/ai/conversation/${result.conversationId}');
      _navigating = false;
      _load();
    } catch (e) {
      // ÖNEMLİ DÜZELTME: Önceden bir hata olduğunda soru sessizce
      // kayboluyordu, kullanıcıya hiçbir şey gösterilmiyordu. Artık
      // hem yazı kutusu korunuyor (tekrar yazmaya gerek yok) hem de
      // anlaşılır bir hata mesajı gösteriliyor.
      if (!mounted) return;
      String message = 'Sorunuz gönderilemedi, tekrar deneyin.';
      if (e is DioException) {
        final serverMessage = e.response?.data?['message'];
        if (serverMessage is String && serverMessage.isNotEmpty) {
          message = serverMessage;
        } else if (e.response?.statusCode == 500) {
          message = 'Sunucu şu an cevap veremiyor. Lütfen daha sonra tekrar deneyin.';
        } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          message = 'Bağlantı zaman aşımına uğradı, tekrar deneyin.';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.navy),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openConversation() async {
    if (_activeConversation == null || _navigating) return;
    _navigating = true;
    await context.push('/ai/conversation/${_activeConversation!['id']}');
    _navigating = false;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppPageHeader(title: AppLocalizations.of(context)!.aiAssistantTitle),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _questionController,
                          decoration: const InputDecoration(hintText: 'Teknik sorunuzu yazın...', border: InputBorder.none, isDense: true),
                          onSubmitted: (_) => _startNewQuestion(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        onPressed: () => context.push('/ai-photo'),
                        icon: const Icon(Icons.camera_alt_outlined),
                        tooltip: 'Fotoğraf ile sor',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.navy.withValues(alpha: 0.06),
                          foregroundColor: AppColors.navy,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filled(
                        onPressed: _submitting ? null : _startNewQuestion,
                        icon: _submitting
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_activeConversation != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'DEVAM EDEN SOHBETİNİZ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.6),
                    ),
                  ),
                  _buildConversationPreview(),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: AppEmptyState(
                      icon: Icons.smart_toy_outlined,
                      title: 'Henüz bir sorunuz yok',
                      description: 'Yukarıdaki kutuya teknik sorunuzu yazarak başlayın.',
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildConversationPreview() {
    final msgs = (_activeConversation!['messages'] as List);
    final userMsg = msgs.firstWhere((m) => m['senderType'] == 'USER', orElse: () => null);
    final aiMsg = msgs.firstWhere((m) => m['senderType'] == 'AI', orElse: () => null);
    final hasPhoto = userMsg?['attachmentUrl'] != null && userMsg?['attachmentType'] == 'image';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        leading: hasPhoto
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  color: AppColors.navy.withValues(alpha: 0.08),
                  child: const Icon(Icons.image_outlined, color: AppColors.navy, size: 18),
                ),
              )
            : Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.navy, AppColors.navyLight]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
              ),
        title: Text(
          userMsg?['content'] ?? aiMsg?['content'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy, letterSpacing: -0.1),
        ),
        subtitle: aiMsg != null
            ? Text(
                aiMsg['content'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              )
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: _openConversation,
      ),
    );
  }
}
