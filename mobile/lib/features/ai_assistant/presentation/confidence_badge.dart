import 'package:flutter/material.dart';
import '../domain/chat_message.dart';

class ConfidenceBadge extends StatelessWidget {
  final Confidence confidence;

  const ConfidenceBadge({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final (label, color, emoji) = switch (confidence) {
      Confidence.high => ('Yüksek Güven', Colors.green, '🟢'),
      Confidence.low => ('Doğrulanmamış', Colors.orange, '🟡'),
      Confidence.none => ('Bilinmiyor', Colors.grey, '⚪'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(color: color.shade700, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
