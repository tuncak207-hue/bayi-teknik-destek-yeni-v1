import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tüm liste ekranlarında (Bayiler, Mesajlar, Randevular, Gruplar vb.)
/// tutarlı, gözden geçirilmiş bir "boş durum" görünümü sağlar. Dairesel,
/// hafif renkli bir ikon zemini + başlık + açıklama + isteğe bağlı eylem
/// butonu içerir.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.navy.withOpacity(0.55)),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.navy),
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
