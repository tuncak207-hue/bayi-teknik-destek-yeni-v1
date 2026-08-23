import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/chat_message.dart';

class CitationCard extends StatelessWidget {
  final Citation citation;

  const CitationCard({super.key, required this.citation});

  /// Kullanıcı isteği: "döküman adı çok uzun, adını kısa tut, uzantısı
  /// ne olursa olsun." Doküman adları genelde uzun teknik dosya adları
  /// (örn. "M-170.1-MA-EN-REVA-MORLEY-2024.pdf") olduğu için, önce dosya
  /// uzantısını kaldırıp, sonra belirli bir uzunluğu aşarsa kısaltıyoruz.
  String get _shortTitle {
    var title = citation.documentTitle;
    // Uzantıyı (.pdf, .docx vb.) kaldır.
    title = title.replaceAll(RegExp(r'\.\w{2,5}$'), '');
    const maxLen = 28;
    if (title.length > maxLen) {
      title = '${title.substring(0, maxLen).trim()}…';
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/documents/${citation.documentId}?page=${citation.page}'),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _shortTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  Text(
                    'Sayfa ${citation.page} · ${citation.brand} ${citation.model}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
