import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';

/// Kullanıcı isteği: "Dijital Cihaz Pasaportu" — devreye alınan her cihaza
/// yapıştırılan QR kodu tarayarak, o cihazın TÜM geçmişini (devreye alma +
/// bağlı bakım kayıtları + teknik destek talepleri) tek ekranda gösterir.
/// Yıllar sonra, başka bir bayinin teknisyeni bile bu kodu tarayarak
/// cihazın hikayesini görebilir.
class DeviceHistoryScreen extends StatefulWidget {
  const DeviceHistoryScreen({super.key});

  @override
  State<DeviceHistoryScreen> createState() => _DeviceHistoryScreenState();
}

class _DeviceHistoryScreenState extends State<DeviceHistoryScreen> {
  final Dio _dio = ApiClient().dio;
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  bool _scanning = true;
  Map<String, dynamic>? _device;
  String? _error;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null) return;
    setState(() => _processing = true);
    await _controller.stop();

    try {
      final res = await _dio.get('/commissioning/device/$code');
      if (!mounted) return;
      setState(() {
        _device = res.data;
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Bu QR koda ait bir cihaz kaydı bulunamadı.';
        _processing = false;
      });
      await _controller.start();
    }
  }

  void _scanAgain() {
    setState(() {
      _device = null;
      _error = null;
      _scanning = true;
      _processing = false;
    });
    _controller.start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: const Text('Cihaz Geçmişi', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
      ),
      body: _scanning ? _buildScanner() : _buildHistory(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14)),
              child: Text(
                _error ?? 'Cihazın üzerindeki QR etiketi kameraya gösterin',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    final d = _device!;
    final maintenanceRecords = (d['maintenanceRecords'] as List?) ?? [];
    final supportTickets = (d['supportTickets'] as List?) ?? [];
    final dealer = d['dealer'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // --- Devreye alma bilgisi (cihazın "doğum kaydı") ---
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_2, color: AppColors.brand, size: 18),
                  const SizedBox(width: 6),
                  const Text('CİHAZ PASAPORTU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.brand, letterSpacing: 0.5)),
                ],
              ),
              const SizedBox(height: 10),
              Text('${d['panelBrand']} ${d['panelModel']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
              if (d['serialNumber'] != null && (d['serialNumber'] as String).isNotEmpty)
                Text('Seri No: ${d['serialNumber']}', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(d['siteName'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              if (dealer != null)
                Text(
                  'Devreye alan: ${dealer['firstName']} ${dealer['lastName']} (${dealer['company']})',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              if (d['completedAt'] != null)
                Text('Devreye alma tarihi: ${_formatDate(d['completedAt'])}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // --- Bakım geçmişi ---
        if (maintenanceRecords.isNotEmpty) ...[
          const Text('Bakım Geçmişi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 8),
          ...maintenanceRecords.map((m) => _TimelineCard(
                icon: Icons.build_outlined,
                color: AppColors.brand,
                title: m['systemDescription'] ?? 'Bakım',
                subtitle: m['notes'] ?? '',
                date: m['performedAt'],
                by: m['createdBy'] != null ? '${m['createdBy']['firstName']} ${m['createdBy']['lastName']}' : null,
              )),
          const SizedBox(height: AppSpacing.lg),
        ],

        // --- Teknik destek geçmişi ---
        if (supportTickets.isNotEmpty) ...[
          const Text('Teknik Destek Geçmişi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 8),
          ...supportTickets.map((t) => _TimelineCard(
                icon: Icons.report_problem_outlined,
                color: Colors.orange.shade700,
                title: t['description'] ?? '',
                subtitle: 'Durum: ${t['status']}',
                date: t['createdAt'],
                by: null,
              )),
        ],

        if (maintenanceRecords.isEmpty && supportTickets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Bu cihaz için henüz bakım/arıza kaydı yok.', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))),
          ),

        const SizedBox(height: AppSpacing.xl),
        Center(
          child: TextButton.icon(
            onPressed: _scanAgain,
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Başka Bir Cihaz Tara'),
          ),
        ),
      ],
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

class _TimelineCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? date;
  final String? by;

  const _TimelineCard({required this.icon, required this.color, required this.title, required this.subtitle, this.date, this.by});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (date != null || by != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [if (date != null) _fmt(date!), if (by != null) by!].join(' · '),
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
