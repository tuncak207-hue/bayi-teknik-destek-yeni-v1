import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/premium_form_widgets.dart';
import 'calculator_pdf_exporter.dart';

class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (icon: Icons.battery_charging_full_outlined, label: AppLocalizations.of(context)!.calcTabBattery),
      (icon: Icons.videocam_outlined, label: AppLocalizations.of(context)!.calcTabCameraHdd),
      (icon: Icons.power_outlined, label: AppLocalizations.of(context)!.calcTabPoe),
    ];
    return Scaffold(
      appBar: AppPageHeader(title: AppLocalizations.of(context)!.screenCalculators),
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: Text(
              'Teknik Hesaplamalar',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navy, letterSpacing: -0.6, height: 1.1),
            ),
          ),
          // Standart alt çizgili TabBar yerine, daha "premium" duran
          // ikonlu bir segment kontrolü.
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFEFF1F4), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.sm), boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 1)),
                ]),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.navy,
                unselectedLabelColor: Colors.grey.shade500,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                tabs: tabs
                    .map((t) => Tab(
                          height: 44,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(t.icon, size: 16),
                              const SizedBox(width: 6),
                              Text(t.label),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _BatteryCalculator(),
                _CameraStorageCalculator(),
                _PoeBudgetCalculator(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Sonuç kartı: en önemli sonucu ("başlık sonuç") büyük ve öne çıkan bir
/// şekilde gösterir, geri kalan detayları altında ikincil satırlar olarak
/// listeler — önceden tüm değerler birbirinden ayırt edilemeyen düz bir
/// liste halindeydi.
class _ResultCard extends StatelessWidget {
  final Map<String, dynamic>? result;
  final String? error;
  final String title;
  final String? headlineKey;
  final String? headlineSuffix;
  final String? statusKey; // boolean bir alan varsa (örn. withinBudget) yeşil/kırmızı rozet gösterir

  const _ResultCard({
    this.result,
    this.error,
    this.title = 'Hesaplama Sonucu',
    this.headlineKey,
    this.headlineSuffix,
    this.statusKey,
  });

  static const _kLabels = {
    'standbyAh': 'Bekleme (standby) Ah',
    'alarmAh': 'Alarm Ah',
    'requiredAh': 'Gerekli toplam Ah',
    'recommendedBatteryAh': 'Önerilen akü',
    'requiredTb': 'Gerekli depolama',
    'recommendedHddTb': 'Önerilen HDD',
    'totalRequiredW': 'Toplam güç ihtiyacı',
    'switchBudgetW': 'Switch bütçesi',
    'utilizationPercent': 'Kullanım oranı',
    'withinBudget': 'Bütçe içinde mi?',
  };

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppSpacing.radius)),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.navy, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(error!, style: const TextStyle(color: AppColors.navy))),
          ],
        ),
      );
    }
    if (result == null) return const SizedBox.shrink();

    final otherEntries = result!.entries.where((e) => e.key != 'note' && e.key != headlineKey && e.key != statusKey).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.subtle,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.check_circle_outline, color: AppColors.brand, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Başlık sonuç — en önemli/önerilen değer, büyük yazıyla.
          if (headlineKey != null && result![headlineKey] != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(color: const Color(0xFFFAFAFB), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Column(
                children: [
                  Text(_kLabels[headlineKey] ?? headlineKey!, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${result![headlineKey]}${headlineSuffix ?? ''}',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.navy),
                  ),
                ],
              ),
            ),

          if (statusKey != null && result![statusKey] != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: result![statusKey] == true ? Colors.green.withValues(alpha: 0.08) : AppColors.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    result![statusKey] == true ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 16,
                    color: result![statusKey] == true ? Colors.green.shade700 : AppColors.navy,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    result![statusKey] == true ? 'Bütçe İçinde' : 'Bütçe Aşıldı',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: result![statusKey] == true ? Colors.green.shade700 : AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (otherEntries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...otherEntries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_kLabels[e.key] ?? e.key, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],

          if (result!['note'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                result!['note'],
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ),

          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => CalculatorPdfExporter.export(context: context, title: title, result: result!, labels: _kLabels),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: Text(AppLocalizations.of(context)!.getPdfReport),
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryCalculator extends StatefulWidget {
  const _BatteryCalculator();

  @override
  State<_BatteryCalculator> createState() => _BatteryCalculatorState();
}

class _BatteryCalculatorState extends State<_BatteryCalculator> {
  final Dio _dio = ApiClient().dio;
  final _standbyController = TextEditingController(text: '200');
  final _alarmController = TextEditingController(text: '1000');
  final _standbyHoursController = TextEditingController(text: '24');
  final _alarmMinutesController = TextEditingController(text: '30');
  Map<String, dynamic>? _result;
  String? _error;
  bool _calculating = false;

  Future<void> _calculate() async {
    setState(() {
      _error = null;
      _result = null;
      _calculating = true;
    });
    try {
      final res = await _dio.post('/calculators/battery', data: {
        'standbyCurrentMa': double.tryParse(_standbyController.text) ?? 0,
        'alarmCurrentMa': double.tryParse(_alarmController.text) ?? 0,
        'standbyHours': double.tryParse(_standbyHoursController.text) ?? 0,
        'alarmMinutes': double.tryParse(_alarmMinutesController.text) ?? 0,
      });
      setState(() => _result = res.data);
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message']?.toString() ?? 'Hesaplama başarısız.');
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _CalculatorIntro(
          icon: Icons.battery_charging_full_outlined,
          text: 'Yangın alarm paneli için gereken yedek akü kapasitesini (Ah), bekleme ve alarm durumundaki akım tüketimine göre hesaplar.',
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumFormSection(
          title: AppLocalizations.of(context)!.calcSystemInfo,
          children: [
            _UnitField(controller: _standbyController, label: AppLocalizations.of(context)!.standbyCurrent, unit: 'mA', icon: Icons.bedtime_outlined),
            _UnitField(controller: _alarmController, label: AppLocalizations.of(context)!.alarmCurrent, unit: 'mA', icon: Icons.notifications_active_outlined),
            _UnitField(controller: _standbyHoursController, label: AppLocalizations.of(context)!.standbyDuration, unit: 'saat', icon: Icons.schedule_outlined),
            _UnitField(controller: _alarmMinutesController, label: AppLocalizations.of(context)!.alarmDuration, unit: 'dk', icon: Icons.timer_outlined, isLast: true),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _calculating ? null : _calculate,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _calculating
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(AppLocalizations.of(context)!.calculate, style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ResultCard(
          result: _result,
          error: _error,
          title: AppLocalizations.of(context)!.calcBatteryCapacity,
          headlineKey: 'recommendedBatteryAh',
          headlineSuffix: ' Ah',
        ),
      ],
    );
  }
}

class _CameraStorageCalculator extends StatefulWidget {
  const _CameraStorageCalculator();

  @override
  State<_CameraStorageCalculator> createState() => _CameraStorageCalculatorState();
}

class _CameraStorageCalculatorState extends State<_CameraStorageCalculator> {
  final Dio _dio = ApiClient().dio;
  final _cameraCountController = TextEditingController(text: '10');
  final _bitrateController = TextEditingController(text: '4');
  final _retentionController = TextEditingController(text: '30');
  Map<String, dynamic>? _result;
  String? _error;
  bool _calculating = false;

  Future<void> _calculate() async {
    setState(() {
      _error = null;
      _result = null;
      _calculating = true;
    });
    try {
      final res = await _dio.post('/calculators/camera-storage', data: {
        'cameraCount': int.tryParse(_cameraCountController.text) ?? 0,
        'bitrateMbps': double.tryParse(_bitrateController.text) ?? 0,
        'retentionDays': int.tryParse(_retentionController.text) ?? 0,
      });
      setState(() => _result = res.data);
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message']?.toString() ?? 'Hesaplama başarısız.');
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _CalculatorIntro(
          icon: Icons.videocam_outlined,
          text: 'Kamera sayısı, bitrate ve saklama süresine göre gereken toplam depolama (TB) kapasitesini hesaplar.',
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumFormSection(
          title: AppLocalizations.of(context)!.calcSystemInfo,
          children: [
            _UnitField(controller: _cameraCountController, label: AppLocalizations.of(context)!.cameraCount, unit: 'adet', icon: Icons.videocam_outlined),
            _UnitField(controller: _bitrateController, label: AppLocalizations.of(context)!.bitratePerCamera, unit: 'Mbps', icon: Icons.speed_outlined),
            _UnitField(controller: _retentionController, label: AppLocalizations.of(context)!.retentionPeriod, unit: 'gün', icon: Icons.calendar_month_outlined, isLast: true),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _calculating ? null : _calculate,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _calculating
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(AppLocalizations.of(context)!.calculate, style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ResultCard(
          result: _result,
          error: _error,
          title: AppLocalizations.of(context)!.calcCameraHdd,
          headlineKey: 'recommendedHddTb',
          headlineSuffix: ' TB',
        ),
      ],
    );
  }
}

class _PoeBudgetCalculator extends StatefulWidget {
  const _PoeBudgetCalculator();

  @override
  State<_PoeBudgetCalculator> createState() => _PoeBudgetCalculatorState();
}

class _PoeBudgetCalculatorState extends State<_PoeBudgetCalculator> {
  final Dio _dio = ApiClient().dio;
  final _wattageController = TextEditingController(text: '10');
  final _countController = TextEditingController(text: '8');
  final _budgetController = TextEditingController(text: '130');
  Map<String, dynamic>? _result;
  String? _error;
  bool _calculating = false;

  Future<void> _calculate() async {
    setState(() {
      _error = null;
      _result = null;
      _calculating = true;
    });
    try {
      final res = await _dio.post('/calculators/poe-budget', data: {
        'devices': [
          {
            'name': 'Kamera',
            'wattage': double.tryParse(_wattageController.text) ?? 0,
            'count': int.tryParse(_countController.text) ?? 0,
          },
        ],
        'switchBudgetW': double.tryParse(_budgetController.text) ?? 0,
      });
      setState(() => _result = res.data);
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message']?.toString() ?? 'Hesaplama başarısız.');
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _CalculatorIntro(
          icon: Icons.power_outlined,
          text: 'Cihaz başına güç tüketimi ve switch\'in toplam PoE bütçesine göre, bütçenin yeterli olup olmadığını hesaplar.',
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumFormSection(
          title: AppLocalizations.of(context)!.calcDeviceInfo,
          children: [
            _UnitField(controller: _wattageController, label: AppLocalizations.of(context)!.wattagePerDevice, unit: 'W', icon: Icons.bolt_outlined),
            _UnitField(controller: _countController, label: AppLocalizations.of(context)!.deviceCount, unit: 'adet', icon: Icons.videocam_outlined),
            _UnitField(controller: _budgetController, label: AppLocalizations.of(context)!.switchPowerBudget, unit: 'W', icon: Icons.dns_outlined, isLast: true),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _calculating ? null : _calculate,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _calculating
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(AppLocalizations.of(context)!.calculate, style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ResultCard(
          result: _result,
          error: _error,
          title: AppLocalizations.of(context)!.calcPoeBudget,
          headlineKey: 'utilizationPercent',
          headlineSuffix: '%',
          statusKey: 'withinBudget',
        ),
      ],
    );
  }
}

/// Her hesaplayıcının üstünde, ne işe yaradığını kısaca anlatan bir tanıtım
/// şeridi — önceden kullanıcı hiçbir açıklama olmadan direkt boş kutularla
/// karşılaşıyordu.
class _CalculatorIntro extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CalculatorIntro({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.navy),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.4))),
        ],
      ),
    );
  }
}

/// Birim etiketli (mA, saat, W vb.) premium giriş alanı.
class _UnitField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final IconData icon;
  final bool isLast;

  const _UnitField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.icon,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade400),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: label, border: InputBorder.none, isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Text(unit, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, indent: 46, color: Colors.grey.shade100),
      ],
    );
  }
}
