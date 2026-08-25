import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Formlar için ortak bölüm başlığı — kullanıcı isteği üzerine (Bakım
/// Geçmişi / Devreye Alma / Malzeme Listesi formlarının tasarımını
/// değiştirme), önceki "tek büyük kart içinde gruplu alanlar" yapısından
/// vazgeçildi. Artık her alan kendi bağımsız, yükseltilmiş (elevated)
/// kartında — odaklanınca öne çıkıyor.
class PremiumFormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final IconData? icon;

  const PremiumFormSection({super.key, required this.title, required this.children, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 14, color: AppColors.navy),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.navy, letterSpacing: -0.1),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

/// Kendi başına duran, odaklanınca canlanan premium metin alanı —
/// eskiden tek bir kart içinde alt alta diziliyordu, artık her biri
/// bağımsız bir "yüzen" kart.
class PremiumField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isLast;
  final int minLines;
  // null = sınırsız satır (alan içerikle birlikte büyür) — kullanıcı
  // isteği: bazı alanlarda "istediğim kadar yazı yazabilmeliyim."
  final int? maxLines;

  const PremiumField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isLast = false,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  State<PremiumField> createState() => _PremiumFieldState();
}

class _PremiumFieldState extends State<PremiumField> {
  bool _focused = false;

  bool get _isMultiline => widget.maxLines == null || widget.maxLines! > 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.isLast ? 0 : AppSpacing.xs),
      child: Focus(
        onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _focused ? AppColors.brand : Colors.grey.shade100, width: _focused ? 1.3 : 1),
            boxShadow: [
              BoxShadow(
                color: _focused ? AppColors.brand.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
                blurRadius: _focused ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
          child: Row(
            crossAxisAlignment: _isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: _isMultiline ? 14 : 0),
                child: Icon(widget.icon, size: 18, color: _focused ? AppColors.brand : Colors.grey.shade400),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines,
                  decoration: InputDecoration(labelText: widget.label, border: InputBorder.none, isDense: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
