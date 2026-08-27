import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'dart:io' show Platform;

import '../theme/app_theme.dart';

/// Alt sayfalar için tek tip başlık ve geri navigasyonu. Ana sekmelerin üst
/// navigasyonu bu bileşeni kullanmaz; yalnızca push edilen alt ekranlarda kullanılır.
class AppPageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Başlığın hemen yanına (ör. bir sayaç rozeti) yerleştirilecek isteğe
  /// bağlı küçük bileşen — "rozet en sağda değil, başlığın yanında olmalı"
  /// isteği için: actions sağ kenara yaslanır, bu ise başlıkla birlikte akar.
  final Widget? titleBadge;

  /// Başlığın geri okuna olan mesafesi — "yazı ortada duruyor, sola yakın
  /// olmalı" gibi tekil isteklerde, bu ekrana özel daraltmak için.
  final double? titleSpacing;

  const AppPageHeader({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
    this.backgroundColor,
    this.foregroundColor,
    this.titleBadge,
    this.titleSpacing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = foregroundColor ?? AppColors.navy;
    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.background,
      foregroundColor: foreground,
      surfaceTintColor: scheme.primary.withValues(alpha: 0.04),
      elevation: 0,
      scrolledUnderElevation: 1,
      toolbarHeight: 64,
      title: titleBadge == null
          ? Text(title, style: AppText.screenTitle.copyWith(color: foreground))
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: AppText.screenTitle.copyWith(color: foreground),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                titleBadge!,
              ],
            ),
      centerTitle: false,
      titleSpacing: titleSpacing,
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Geri',
        color: foreground,
        icon: const Icon(Icons.arrow_back),
        onPressed:
            onBack ??
            () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/home');
              }
            },
      ),
      actions: actions,
    );
  }
}

enum AppStatusTone { success, inProgress, pending, danger, neutral }

/// Küçük, yuvarlatılmış durum rozeti — "Tamamlandı", "Devam Ediyor",
/// "Bekliyor", "Hata" gibi durumlar için. Renkler bağırmayan, açık tonlar.
class StatusBadge extends StatelessWidget {
  final String label;
  final AppStatusTone tone;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

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
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.fg,
            ),
          ),
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

  const StandardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.md,
    ),
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surfaceContainerLow
            : const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border:
            border ??
            Border.all(
              color: Theme.of(context).colorScheme.outlineVariant
                  .withValues(alpha: 0.72),
            ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow
                .withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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

  const CardHeaderRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

/// Sağ altta sabit, sade "+ Yeni ..." aksiyon butonu.
class StandardFab extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  const StandardFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      elevation: 2,
      extendedIconLabelSpacing: 8,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
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
    final scheme = Theme.of(context).colorScheme;
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: scheme.surface,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: scheme.surface,
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
            ),
          ),
          middle: Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: canSubmit && !submitting ? onSubmit : null,
            child: submitting
                ? const CupertinoActivityIndicator()
                : Text(
                    submitLabel,
                    style: TextStyle(
                      color: canSubmit
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.45),
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
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        surfaceTintColor: scheme.surface,
        automaticallyImplyLeading: true,
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: canSubmit && !submitting ? onSubmit : null,
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      submitLabel.toUpperCase(),
                      style: TextStyle(
                        color: canSubmit
                            ? scheme.primary
                            : scheme.onSurfaceVariant.withValues(alpha: 0.45),
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
    final scheme = Theme.of(context).colorScheme;
    if (Platform.isIOS) {
      return CupertinoTextField.borderless(
        controller: controller,
        onChanged: onChanged,
        placeholder: hint,
        placeholderStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: scheme.onSurface,
          height: 1.4,
        ),
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
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: scheme.onSurface,
        height: 1.4,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
