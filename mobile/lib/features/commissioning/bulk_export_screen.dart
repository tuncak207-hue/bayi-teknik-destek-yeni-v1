import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/current_user.dart';
import '../../core/pdf/document_pdf_exporter.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Kullanıcı isteği: "Toplu PDF Dışa Aktarma" — belirli bir tarih
/// aralığındaki TÜM devreye alma raporlarını tek seferde PDF'e çevirip
/// bir ZIP dosyasında dışa aktarır. Dönem sonu muhasebe/arşivleme işini
/// tek tek dosya indirmek yerine tek dokunuşa indirger.
class BulkExportScreen extends StatefulWidget {
  const BulkExportScreen({super.key});

  @override
  State<BulkExportScreen> createState() => _BulkExportScreenState();
}

class _BulkExportScreenState extends State<BulkExportScreen> {
  final Dio _dio = ApiClient().dio;
  DateTimeRange? _range;
  bool _exporting = false;
  String _status = '';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _export() async {
    if (_range == null) return;
    setState(() {
      _exporting = true;
      _status = 'Raporlar getiriliyor...';
    });

    try {
      final res = await _dio.get('/commissioning/reports');
      final allReports = (res.data as List?) ?? [];
      final filtered = allReports.where((r) {
        final created = DateTime.tryParse(r['createdAt'] ?? '');
        if (created == null) return false;
        return created.isAfter(_range!.start.subtract(const Duration(days: 1))) &&
            created.isBefore(_range!.end.add(const Duration(days: 1)));
      }).toList();

      if (filtered.isEmpty) {
        setState(() {
          _exporting = false;
          _status = 'Seçilen aralıkta rapor bulunamadı.';
        });
        return;
      }

      final archive = Archive();
      for (var i = 0; i < filtered.length; i++) {
        final r = filtered[i];
        setState(() => _status = 'PDF oluşturuluyor (${i + 1}/${filtered.length})...');

        Uint8List? signatureBytes;
        if (r['signatureUrl'] != null) {
          try {
            signatureBytes = await DocumentPdfExporter.downloadSignature(_dio, '/commissioning/reports/${r['id']}/signature-url');
          } catch (_) {
            // İmza indirilemezse PDF imzasız üretilir — dışa aktarma durmaz.
          }
        }

        final items = (r['items'] as List?) ?? [];
        final file = await DocumentPdfExporter.build(
          documentTitle: 'Devreye Alma Raporu — ${r['siteName']}',
          dealerName: '${CurrentUser().firstName} ${CurrentUser().lastName}',
          dealerCompany: '',
          customerName: r['customerName'],
          infoRows: [
            (label: AppLocalizations.of(context)!.panelLabel, value: '${r['panelBrand']} ${r['panelModel']}'),
          ],
          checklist: items.map((it) => (label: it['label'] as String, checked: it['checked'] == true)).toList(),
          notes: r['notes'],
          signatureBytes: signatureBytes,
        );

        final bytes = await file.readAsBytes();
        final safeName = (r['siteName'] as String? ?? 'rapor').replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞİÖÇ-]'), '');
        archive.addFile(ArchiveFile('$safeName-${i + 1}.pdf', bytes.length, bytes));
      }

      setState(() => _status = 'ZIP paketleniyor...');
      final zipData = ZipEncoder().encode(archive);
      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/devreye-alma-raporlari-${DateTime.now().millisecondsSinceEpoch}.zip');
      await zipFile.writeAsBytes(zipData);

      if (!mounted) return;
      await Share.shareXFiles([XFile(zipFile.path)], text: '${filtered.length} devreye alma raporu');

      setState(() {
        _exporting = false;
        _status = '${filtered.length} rapor başarıyla dışa aktarıldı.';
      });
    } catch (e) {
      setState(() {
        _exporting = false;
        _status = 'Dışa aktarma başarısız: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: const Text('Toplu PDF Dışa Aktarma', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Belirli bir tarih aralığındaki tüm devreye alma raporlarını tek bir ZIP dosyasında dışa aktarın.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: AppSpacing.lg),
            InkWell(
              onTap: _exporting ? null : _pickRange,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.outlineStrong),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: AppColors.brand),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _range == null
                            ? 'Tarih aralığı seçin'
                            : '${_fmt(_range!.start)} — ${_fmt(_range!.end)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_range == null || _exporting) ? null : _export,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _exporting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Dışa Aktar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_status, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
