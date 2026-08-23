import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Kullanıcı isteği: "UI tarafında tekrar eden yapıları reusable
/// component haline getir." Bu dosya, uygulamanın tüm ekranlarında
/// AYNI görsel dili kullanacak temel bileşenleri içerir. Bir ekrandaki
/// buton, başka bir ekranda FARKLI görünmemeli — bu dosya bunu garanti
/// eder.

// ============================================================
// APP BUTTON — Primary / Secondary / Tertiary / Destructive
// ============================================================

enum AppButtonVariant { primary, secondary, tertiary, destructive }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.tertiary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.tertiary;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AppButtonVariant.primary || variant == AppButtonVariant.destructive
                  ? Colors.white
                  : AppColors.textPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: AppSpacing.xxs + 2)],
              Text(label),
            ],
          );

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.1),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: AppColors.outlineStrong, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.1),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.tertiary:
        button = TextButton(
          onPressed: loading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          ),
          child: child,
        );
        break;
      case AppButtonVariant.destructive:
        button = ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorContainer,
            foregroundColor: AppColors.errorColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          child: child,
        );
        break;
    }

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

// ============================================================
// APP TEXT FIELD — Focus / Error / Disabled / Filled durumları
// ============================================================

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? helperText;
  final String? errorText;
  final IconData? icon;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final int minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.helperText,
    this.errorText,
    this.icon,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final borderColor = !widget.enabled
        ? AppColors.outline
        : hasError
            ? AppColors.errorColor
            : _focused
                ? AppColors.primary
                : AppColors.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: widget.enabled ? AppColors.surfaceBase : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: borderColor, width: (_focused || hasError) ? 1.4 : 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
            child: Row(
              crossAxisAlignment: (widget.maxLines ?? 1) > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Padding(
                    padding: EdgeInsets.only(top: (widget.maxLines ?? 1) > 1 ? 14 : 0),
                    child: Icon(widget.icon, size: 18, color: hasError ? AppColors.errorColor : (_focused ? AppColors.primary : AppColors.textMuted)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    enabled: widget.enabled,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    minLines: widget.minLines,
                    maxLines: widget.obscureText ? 1 : widget.maxLines,
                    onChanged: widget.onChanged,
                    onSubmitted: (_) => widget.onSubmitted?.call(),
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: widget.label,
                      labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 14.5),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError || widget.helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs, left: 4),
            child: Text(
              hasError ? widget.errorText! : widget.helperText!,
              style: TextStyle(fontSize: 12, color: hasError ? AppColors.errorColor : AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// APP CARD — ince kenarlık, çok hafif gölge, tutarlı padding
// ============================================================

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool elevated;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    // Kullanıcı isteği: "Kartların etrafındaki ince gri border'lar fazla
    // belirgin... Gereksiz border'ları kaldır. Çok hafif shadow/elevation
    // kullan." Kenarlık kaldırıldı, çok hafif gölge geri getirildi —
    // kartlar artık çizgiyle çevrelenmiş kutular gibi değil, arka
    // plandan hafifçe "yükselerek" ayrışıyor.
    final content = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: elevated ? AppShadows.card : AppShadows.subtle,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

// ============================================================
// APP BADGE — durum/etiket rozeti
// ============================================================

enum AppBadgeTone { neutral, success, warning, error, info, brand }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeTone tone;
  final IconData? icon;

  const AppBadge({super.key, required this.label, this.tone = AppBadgeTone.neutral, this.icon});

  (Color, Color) get _colors => switch (tone) {
        AppBadgeTone.success => (AppColors.successContainer, AppColors.successColor),
        AppBadgeTone.warning => (AppColors.warningContainer, AppColors.warningColor),
        AppBadgeTone.error => (AppColors.errorContainer, AppColors.errorColor),
        AppBadgeTone.info => (AppColors.infoContainer, AppColors.infoColor),
        AppBadgeTone.brand => (AppColors.primaryContainer, AppColors.primary),
        AppBadgeTone.neutral => (AppColors.surfaceVariant, AppColors.textSecondary),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

// ============================================================
// APP EMPTY STATE — icon + başlık + açıklama + opsiyonel aksiyon
// ============================================================

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.surfaceVariant, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.4),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(label: actionLabel!, onPressed: onAction, fullWidth: false),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// APP LOADING STATE — shimmer/skeleton, sadece dönen ikon değil
// ============================================================

class AppLoadingState extends StatelessWidget {
  final int lines;
  const AppLoadingState({super.key, this.lines = 4});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: Colors.white,
      child: Column(
        children: List.generate(
          lines,
          (i) => Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// APP ERROR STATE — kullanıcı dostu mesaj + retry aksiyonu
// ============================================================

class AppErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const AppErrorState({super.key, this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.errorContainer, shape: BoxShape.circle),
            child: Icon(Icons.wifi_off_rounded, size: 28, color: AppColors.errorColor),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Bir şeyler ters gitti',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            message ?? 'Veriler yüklenemedi. İnternet bağlantınızı kontrol edip tekrar deneyin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.secondary(label: 'Tekrar Dene', onPressed: onRetry, icon: Icons.refresh, fullWidth: false),
        ],
      ),
    );
  }
}
