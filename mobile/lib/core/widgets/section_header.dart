import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bir listenin/bölümün üstünde kullanılan, ikonlu tutarlı başlık.
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.navy),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                color: AppColors.navy,
                letterSpacing: 0.1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Küçük, dolgun renkli durum rozeti (Onaylandı / Bekliyor / vb.) —
/// önceden birkaç ekranda ayrı ayrı yazılmıştı, artık tek bir yerden.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// İkon rozetli, tutarlı avatar dairesi — bayi/kullanıcı baş harfi ya da
/// bir ikon göstermek için listelerde tekrarlanan kalıp.
class IconAvatar extends StatelessWidget {
  final IconData? icon;
  final String? initial;
  final Color color;

  const IconAvatar({super.key, this.icon, this.initial, required this.color});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withValues(alpha: 0.12),
      child: icon != null
          ? Icon(icon, color: color, size: 20)
          : Text(
              initial ?? '?',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
    );
  }
}
