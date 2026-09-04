import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';

/// 1a kart-içi düzeni — sola dayalı, üç bölgeli iskelet.
///
/// head    : başlık + metadata satırı (solda), durum rozeti (sağda)
/// body    : açıklama, bilgi ızgarası veya serbest içerik
/// actions : hairline ayrımın altındaki aksiyon çubuğu
///
/// Üç bölge de opsiyoneldir; verilmeyen bölge hiç yer kaplamaz.
/// Yüzey değerleri (renk, köşe, gölge, kenarlık) tamamen mevcut
/// temadan gelir — bu dosya hiçbir yeni renk tanımlamaz.
class AppInfoCard extends StatelessWidget {
  final Widget? head;
  final Widget? body;
  final Widget? actions;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Genelde ihtiyaç duyulmaz — varsayılan `AppColors.outline` hairline
  /// kenarlık kullanılır. Acil/uyarı durumları gibi tek tük istisnalar
  /// için (örn. teknik destek listesinde acil kayıt vurgusu) burada
  /// override edilebilir.
  final Border? border;

  const AppInfoCard({
    super.key,
    this.head,
    this.body,
    this.actions,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (head != null) head!,
          if (body != null) ...[
            if (head != null) const SizedBox(height: 10),
            body!,
          ],
          if (actions != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
            const SizedBox(height: AppSpacing.sm),
            actions!,
          ],
        ],
      ),
    );

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: border ?? Border.all(color: AppColors.outline),
        boxShadow: AppShadows.subtle,
      ),
      child: content,
    );

    if (onTap == null) return surface;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: surface,
      ),
    );
  }
}

/// head bölgesinin standart hali: başlık + nokta ayraçlı metadata satırı,
/// sağda durum rozeti.
class AppInfoCardHead extends StatelessWidget {
  final String title;

  /// Nokta ile ayrılarak tek satırda gösterilir: ['#4821', 'Isıtma', '2 saat önce']
  final List<String> meta;
  final Widget? badge;
  final int titleMaxLines;

  const AppInfoCardHead({
    super.key,
    required this.title,
    this.meta = const [],
    this.badge,
    this.titleMaxLines = 2,
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
                maxLines: titleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  letterSpacing: -0.2,
                  height: 1.3,
                ),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  meta.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: AppSpacing.sm),
          badge!,
        ],
      ],
    );
  }
}

/// Durum rozeti — mevcut AppBadge'in nokta göstergeli hali.
class AppStatusBadge extends StatelessWidget {
  final String label;
  final AppBadgeTone tone;

  const AppStatusBadge({super.key, required this.label, this.tone = AppBadgeTone.neutral});

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
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// body bölgesinin en sık hali: 2 satırla sınırlı özet metni.
class AppInfoCardSummary extends StatelessWidget {
  final String text;
  final int maxLines;

  const AppInfoCardSummary(this.text, {super.key, this.maxLines = 2});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
    );
  }
}

/// body bölgesi için 2x2 bilgi ızgarası (talep detayı: SLA / atanan / cihaz / ek).
class AppInfoGrid extends StatelessWidget {
  /// (etiket, değer, değer rengi) — renk verilmezse navy kullanılır.
  final List<(String, String, Color?)> items;

  const AppInfoGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
        childAspectRatio: 2.6,
        padding: EdgeInsets.zero,
        children: items
            .map((it) => Container(
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(it.$1,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                      const SizedBox(height: 5),
                      Text(it.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: it.$3 ?? AppColors.navy)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

const _kMonthsTr = [
  'OCA', 'ŞUB', 'MAR', 'NİS', 'MAY', 'HAZ',
  'TEM', 'AĞU', 'EYL', 'EKİ', 'KAS', 'ARA',
];
const _kWeekdaysTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// Randevu / ziyaret / eğitim kartlarının solunda kullanılan 52px tarih
/// bloğu (ay / gün / gün adı). `AppInfoCard`'ın `head`'ine `Row` ile eklenir.
class AppDateBlock extends StatelessWidget {
  final DateTime? date;
  const AppDateBlock({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final d = date;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: d == null
          ? const Icon(Icons.event_outlined, color: AppColors.primary, size: 20)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_kMonthsTr[d.month - 1],
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                Text('${d.day}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy, height: 1.1)),
                Text(_kWeekdaysTr[d.weekday - 1],
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              ],
            ),
    );
  }
}

/// 44px baş harf kutusu — bayi/grup kartlarında `head`'e eklenir.
class AppInitialBox extends StatelessWidget {
  final String label;
  final Color? background;
  final Color? foreground;

  const AppInitialBox({super.key, required this.label, this.background, this.foreground});

  @override
  Widget build(BuildContext context) {
    final letter = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: background ?? AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: foreground ?? AppColors.primary),
      ),
    );
  }
}

/// actions bölgesi: solda opsiyonel meta (örn. talep sahibi), sağda butonlar.
/// Satır içi butonlar 40, tam genişlik butonlar 48 yüksekliğinde.
class AppInfoCardActions extends StatelessWidget {
  final Widget? leading;
  final List<Widget> buttons;

  const AppInfoCardActions({super.key, this.leading, required this.buttons});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) Expanded(child: leading!) else const Spacer(),
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          buttons[i],
        ],
      ],
    );
  }
}

/// Kullanım — teknik destek listesi kartı:
///
/// AppInfoCard(
///   onTap: () => context.push('/support-tickets/$id'),
///   head: AppInfoCardHead(
///     title: 'Kombi ateşleme hatası E04',
///     meta: const ['#4821', 'Isıtma', '2 saat önce'],
///     badge: const AppStatusBadge(label: 'Beklemede', tone: AppBadgeTone.warning),
///   ),
///   body: const AppInfoCardSummary('Bayi sahada; cihaz ilk çalıştırmada kilitleniyor.'),
///   actions: AppInfoCardActions(
///     leading: const Text('M. Tuncak'),
///     buttons: [
///       AppButton.secondary(label: 'Yanıtla', onPressed: reply, fullWidth: false),
///       AppButton(label: 'Detay', onPressed: open, fullWidth: false),
///     ],
///   ),
/// )
