import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/chat_message.dart';
import 'confidence_badge.dart';
import 'citation_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback? onFavorite;
  // AI Teknik Soru Hafızası — bu cevap geçmiş, doğrulanmış bir kayıttan
  // mı geldi? Kullanıcı isteği: AI cevabının üzerinde küçük bir bilgi
  // göstergesi olsun: "Bu soru daha önce yanıtlandı."
  final bool fromMemory;
  // Kullanıcı isteği: "cevaba doğrulama ikonu koy, cevap doğruysa
  // mühendislik hafızası çalışsın" — bu cevabın arkasında bir AI Teknik
  // Hafıza kaydı varsa (canVerify), bir "Doğrula" ikonu gösterilir.
  final bool canVerify;
  final bool isVerified;
  final VoidCallback? onVerify;

  const MessageBubble({
    super.key,
    required this.message,
    this.onFavorite,
    this.fromMemory = false,
    this.canVerify = false,
    this.isVerified = false,
    this.onVerify,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final Dio _dio = ApiClient().dio;
  String? _feedback; // 'UP' | 'DOWN' | null
  // Hafızadan gelen cevaplarda kaynaklar varsayılan gizli, "Kaynakları
  // Gör" butonuyla açılır — kullanıcı isteği: "İstenirse: Kaynakları Gör
  // butonu ile önceki cevabın hangi teknik dokümanlara dayandığı
  // gösterilsin."
  bool _showCitations = false;

  ChatMessage get message => widget.message;
  bool get isAi => message.senderType == SenderType.ai;

  Future<void> _sendFeedback(String value) async {
    final newValue = _feedback == value ? null : value; // tekrar basınca geri al
    setState(() => _feedback = newValue);
    try {
      await _dio.post('/chat/messages/${message.id}/feedback', data: {'feedback': newValue});
    } catch (_) {
      // Sessizce yut — geri bildirim ikincil bir özellik, kullanıcı akışını bozmasın.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Column(
          crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            // Kullanıcı isteği: "soran ile cevaplayan belli olsun, soranda
            // ben yazsın, cevaplayanda ENTPA AI yazsın, tarih saat belli
            // olsun."
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAi) ...[
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                      child: const Icon(Icons.bolt, size: 10, color: Colors.white),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    isAi ? 'ENTPA AI' : 'Ben',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.1),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTimestamp(message.createdAt),
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isAi ? Colors.white : AppColors.navy,
                borderRadius: BorderRadius.circular(16),
                border: isAi ? Border.all(color: Colors.grey.shade200) : null,
                boxShadow: isAi
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAi)
                    MarkdownBody(data: message.content, selectable: true)
                  else
                    Text(message.content, style: const TextStyle(color: Colors.white)),
                  if (isAi) ...[
                    const SizedBox(height: 8),
                    if (widget.fromMemory)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 12, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Bu soru daha önce yanıtlandı — önceki doğrulanmış teknik cevap kullanıldı.',
                          style: TextStyle(fontSize: 10.5, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ConfidenceBadge(confidence: message.confidence),
              if (message.citations.isNotEmpty) ...[
                if (widget.fromMemory) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => setState(() => _showCitations = !_showCitations),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    icon: Icon(_showCitations ? Icons.expand_less : Icons.expand_more, size: 15),
                    label: Text(_showCitations ? 'Kaynakları Gizle' : 'Kaynakları Gör', style: const TextStyle(fontSize: 11.5)),
                  ),
                  if (_showCitations) ...[
                    const SizedBox(height: 4),
                    ...message.citations.map((c) => CitationCard(citation: c)),
                  ],
                ] else ...[
                  const SizedBox(height: 4),
                  const Text('Kaynak', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                  ...message.citations.map((c) => CitationCard(citation: c)),
                ],
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.canVerify)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        widget.isVerified ? Icons.verified : Icons.verified_outlined,
                        size: 18,
                        color: widget.isVerified ? Colors.green.shade600 : Colors.grey.shade500,
                      ),
                      onPressed: widget.isVerified ? null : widget.onVerify,
                      tooltip: widget.isVerified ? 'Doğrulandı' : 'Bu cevap doğru — doğrula',
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    onPressed: () => Clipboard.setData(ClipboardData(text: message.content)),
                    tooltip: 'Kopyala',
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    onPressed: () => Share.share(message.content),
                    tooltip: 'Paylaş',
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.bookmark_border, size: 18),
                    onPressed: widget.onFavorite,
                    tooltip: 'Kaydet',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.thumb_up_outlined,
                      size: 17,
                      color: _feedback == 'UP' ? AppColors.brand : Colors.grey.shade500,
                    ),
                    onPressed: () => _sendFeedback('UP'),
                    tooltip: 'Faydalı',
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.thumb_down_outlined,
                      size: 17,
                      color: _feedback == 'DOWN' ? AppColors.brand : Colors.grey.shade500,
                    ),
                    onPressed: () => _sendFeedback('DOWN'),
                    tooltip: 'Faydalı değil',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ],
    ),
    ),
    );
  }
}

String _formatTimestamp(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
  final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  if (isToday) return time;
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} $time';
}
