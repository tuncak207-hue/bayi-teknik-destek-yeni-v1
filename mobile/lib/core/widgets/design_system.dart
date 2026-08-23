import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import '../theme/app_theme.dart';

enum AppStatusTone { success, inProgress, pending, danger, neutral }

/// Küçük, yuvarlatılmış durum rozeti — "Tamamlandı", "Devam Ediyor",
/// "Bekliyor", "Hata" gibi durumlar için. Renkler bağırmayan, açık tonlar.
class StatusBadge extends StatelessWidget {
  final String label;
  final AppStatusTone tone;
  final IconData? icon;

  const StatusBadge({super.key, required this.label, required this.tone, this.icon});

  ({Color bg, Color fg}) get _colors {
    switch (tone) {
      case AppStatusTone.success:
        return (bg: const Color(0xFFE6F4EA), fg: const Color(0xFF1E7A3D));
      case AppStatusTone.inProgress:
        return (bg: const Color(0xFFE8EEF7), fg: const Color(0xFF2A5C9A));
      case AppStatusTone.pending:
        return (bg: const Color(0xFFFCF3E3), fg: const Color(0xFF9A6B14));
      case AppStatusTone.danger:
        return (bg: const Color(0xFFFBEAEA), fg: const Color(0xFFB3261E));
      case AppStatusTone.neutral:
        return (bg: const Color(0xFFF0F1F3), fg: const Color(0xFF5A6472));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: c.fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.fg)),
        ],
      ),
    );
  }
}

/// Standart beyaz, yuvarlatılmış, hafif gölgeli kart.
class StandardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Border? border;

  const StandardCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.md), this.onTap, this.border});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: border,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Liste ekranlarında tekrarlayan üst yapı: başlık + isteğe bağlı
/// açıklama + isteğe bağlı sağ üst rozet/ikon.
class CardHeaderRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const CardHeaderRow({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.navy), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Kartın alt bölümünde küçük, düzenli yardımcı bilgi (tarih, ilerleme vb.).
class CardFooterMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const CardFooterMeta({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
      ],
    );
  }
}

/// Sağ altta sabit, sade "+ Yeni ..." aksiyon butonu.
class StandardFab extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  const StandardFab({super.key, required this.label, required this.onPressed, this.icon = Icons.add});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 2,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

/// Oluşturma/düzenleme formları için platform-uyumlu iskelet — iOS'ta
/// Cupertino navigasyon çubuğu (sol "İptal", sağ mavi eylem metni),
/// Android'de Material AppBar ("İPTAL"/eylem büyük harfli buton)
/// kullanır. Kullanıcı isteği: "android ve ios görünümüne çevir" — bu
/// tekrar kullanılabilir bileşen, bunu tüm oluşturma formlarına hızlıca
/// yaymak için kuruldu.
class PlatformFormScaffold extends StatelessWidget {
  final String title;
  final String submitLabel;
  final bool canSubmit;
  final bool submitting;
  final VoidCallback onSubmit;
  final Widget body;
  final Widget? bottomBar;

  const PlatformFormScaffold({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.canSubmit,
    required this.submitting,
    required this.onSubmit,
    required this.body,
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: CupertinoColors.white,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoColors.white,
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 16)),
          ),
          middle: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: canSubmit && !submitting ? onSubmit : null,
            child: submitting
                ? const CupertinoActivityIndicator()
                : Text(
                    submitLabel,
                    style: TextStyle(
                      color: canSubmit ? CupertinoColors.activeBlue : CupertinoColors.systemGrey3,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: body),
              if (bottomBar != null) bottomBar!,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Colors.black)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: canSubmit && !submitting ? onSubmit : null,
              child: submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      submitLabel.toUpperCase(),
                      style: TextStyle(
                        color: canSubmit ? Colors.black : Colors.grey.shade300,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: body),
            if (bottomBar != null) bottomBar!,
          ],
        ),
      ),
    );
  }
}

/// Formların içindeki, iki platformda da uygun görünen sade metin
/// giriş alanı (kutu/kenarlık yok — PlatformFormScaffold ile birlikte
/// kullanılır).
class PlatformTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? minLines;
  final int? maxLines;
  final double fontSize;
  final FontWeight fontWeight;
  final ValueChanged<String>? onChanged;

  const PlatformTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.minLines,
    this.maxLines = 1,
    this.fontSize = 16,
    this.fontWeight = FontWeight.normal,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoTextField.borderless(
        controller: controller,
        onChanged: onChanged,
        placeholder: hint,
        placeholderStyle: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: CupertinoColors.systemGrey3),
        style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: CupertinoColors.black, height: 1.4),
        padding: EdgeInsets.zero,
        minLines: minLines,
        maxLines: maxLines,
      );
    }
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: Colors.black, height: 1.4),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: Colors.grey.shade300),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
