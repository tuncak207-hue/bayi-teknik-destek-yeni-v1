import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/current_user.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/premium_form_widgets.dart';
import '../../core/widgets/signature_pad.dart';
import '../../core/pdf/document_pdf_exporter.dart';

/// Dijital servis defteri: bir sahada yapılan bakımı (bina adı, sistem
/// açıklaması, notlar) kaydeder, isteğe bağlı olarak müşteri imzası
/// (ekranda parmakla çizilerek) ekler.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/maintenance/records');
    setState(() {
      _records = res.data;
      _loading = false;
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _CreateMaintenanceScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openDetail(dynamic record) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _MaintenanceDetailScreen(record: record),
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _delete(String id) async {
    await _dio.delete('/maintenance/records/$id');
    _load();
  }

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      floatingActionButton: StandardFab(
        label: 'Yeni Kayıt',
        onPressed: _openCreate,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Bakım Geçmişi', style: AppText.screenTitle),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${_records.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        children: [
                          const SizedBox(height: 72),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: StandardCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.xl,
                              ),
                              child: const AppEmptyState(
                                icon: Icons.build_outlined,
                                title: 'Henüz bir bakım kaydınız yok',
                                description: 'Sahada tamamladığınız bakımları burada dijital olarak kaydedebilirsiniz.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _records.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final r = _records[index];
                          final hasSignature = r['signatureUrl'] != null;
                          return StandardCard(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            onTap: () => _openDetail(r),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.navy.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.build_outlined,
                                    color: AppColors.navy,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r['siteName'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      if ((r['systemDescription'] as String?)
                                              ?.isNotEmpty ==
                                          true) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          r['systemDescription'],
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          CardFooterMeta(
                                            icon: Icons.event_outlined,
                                            label: _formatDate(
                                              r['performedAt'],
                                            ),
                                          ),
                                          if (hasSignature) ...[
                                            const SizedBox(width: 8),
                                            const StatusBadge(
                                              label: 'İmzalı',
                                              tone: AppStatusTone.success,
                                              icon: Icons.draw_outlined,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 19,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => _openDetail(r),
                                  tooltip: 'Düzenle',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => _delete(r['id']),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kayıt detayı — içerik düzenlenebilir, PDF olarak alınıp paylaşılabilir.
class _MaintenanceDetailScreen extends StatefulWidget {
  final dynamic record;
  const _MaintenanceDetailScreen({required this.record});

  @override
  State<_MaintenanceDetailScreen> createState() =>
      _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<_MaintenanceDetailScreen> {
  final Dio _dio = ApiClient().dio;
  late final _siteName = TextEditingController(text: widget.record['siteName']);
  late final _systemDescription = TextEditingController(
    text: widget.record['systemDescription'] ?? '',
  );
  late final _notes = TextEditingController(text: widget.record['notes']);
  bool _saving = false;
  bool _exporting = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _dio.patch(
        '/maintenance/records/${widget.record['id']}',
        data: {
          'siteName': _siteName.text.trim(),
          'systemDescription': _systemDescription.text.trim(),
          'notes': _notes.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf({required bool andShare}) async {
    setState(() => _exporting = true);
    try {
      Uint8List? signatureBytes;
      if (widget.record['signatureUrl'] != null) {
        signatureBytes = await DocumentPdfExporter.downloadSignature(
          _dio,
          '/maintenance/records/${widget.record['id']}/signature-url',
        );
      }
      final file = await DocumentPdfExporter.build(
        documentTitle: 'Bakım Raporu — ${_siteName.text}',
        dealerName: '${CurrentUser().firstName} ${CurrentUser().lastName}',
        dealerCompany: '',
        infoRows: [
          if (_systemDescription.text.isNotEmpty)
            (label: 'Sistem', value: _systemDescription.text),
        ],
        notes: _notes.text,
        signatureBytes: signatureBytes,
      );
      if (andShare) {
        await DocumentPdfExporter.share(file);
      } else {
        await DocumentPdfExporter.view(file);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppPageHeader(
        title: 'Bakım Kaydı',
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'view') _exportPdf(andShare: false);
                if (v == 'share') _exportPdf(andShare: true);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Text('PDF Görüntüle'),
                ),
                const PopupMenuItem(value: 'share', child: Text('PDF Paylaş')),
              ],
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          PremiumFormSection(
            title: 'Saha Bilgileri',
            children: [
              PremiumField(
                controller: _siteName,
                label: 'Bina / Tesis Adı',
                icon: Icons.location_on_outlined,
              ),
              PremiumField(
                controller: _systemDescription,
                label: 'Sistem Açıklaması',
                icon: Icons.memory_outlined,
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumFormSection(
            title: 'Yapılan İşlem',
            children: [
              // Kullanıcı isteği: "istediğim kadar yazı yazabilmeliyim" —
              // maxLines sınırı kaldırıldı, alan içerikle birlikte
              // büyüyor.
              PremiumField(
                controller: _notes,
                label: 'Notlar',
                icon: Icons.edit_note_outlined,
                minLines: 3,
                maxLines: null,
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.record['signatureUrl'] != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.draw_outlined,
                    color: Colors.green.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Bu kayıtta müşteri imzası mevcut — PDF\'e dahil edilir.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Değişiklikleri Kaydet',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateMaintenanceScreen extends StatefulWidget {
  const _CreateMaintenanceScreen();

  @override
  State<_CreateMaintenanceScreen> createState() =>
      _CreateMaintenanceScreenState();
}

class _CreateMaintenanceScreenState extends State<_CreateMaintenanceScreen> {
  final Dio _dio = ApiClient().dio;
  final _siteName = TextEditingController();
  final _systemDescription = TextEditingController();
  final _notes = TextEditingController();
  final _signatureKey = GlobalKey<SignaturePadState>();
  bool _submitting = false;
  // "Ekranda çizgi oluşuyor" düzeltmesi: parmak imza kutusundayken listeyi
  // kaydırılamaz yapıp, kutunun üzerinden geçen kaydırma hareketlerinin
  // yanlışlıkla imza olarak kaydedilmesini engelliyor.
  bool _signing = false;

  Future<void> _submit() async {
    if (_siteName.text.trim().isEmpty || _notes.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen en azından bina adı ve yapılan işlemi girin.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await _dio.post(
        '/maintenance/records',
        data: {
          'siteName': _siteName.text.trim(),
          'systemDescription': _systemDescription.text.trim(),
          'notes': _notes.text.trim(),
        },
      );
      final recordId = res.data['id'];

      final padState = _signatureKey.currentState;
      if (padState != null && padState.hasSignature) {
        final bytes = await padState.renderToPng();
        if (bytes != null) {
          final formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes, filename: 'imza.png'),
          });
          await _dio.post(
            '/maintenance/records/$recordId/signature',
            data: formData,
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: Color(0xFFFFFFFF),
          border: null,
          middle: Text(
            'Yeni Bakım Kaydı',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        child: SafeArea(child: _buildForm()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: const AppPageHeader(title: 'Yeni Bakım Kaydı'),
      // ÖNEMLİ DÜZELTME: Android'de SafeArea eksikti, alttaki sabit
      // "Kaydet" butonu sistem gezinme çubuğunun arkasında kalıyordu.
      body: SafeArea(child: _buildForm()),
    );
  }

  Widget _buildForm() {
    // ÖNEMLİ DÜZELTME: "Kaydet yazısı sayfanın altında kayboluyor" —
    // buton, kaydırılabilir listenin son öğesiydi ve altında sadece
    // standart bir kenar boşluğu vardı. Klavye açıkken veya cihazın alt
    // hareket çubuğu/güvenli alanı geniş olduğunda bu, butonun (veya
    // yazısının) ekranın en altına yapışıp kırpılmış görünmesine yol
    // açıyordu. Artık altta hem klavye yüksekliği hem de cihazın güvenli
    // alanı + bolca ekstra pay hesaba katılıyor. Kullanıcı butonun hâlâ
    // alt kenara çok yakın olduğunu belirtti, bu yüzden pay bir kez daha
    // artırıldı — buton artık ekranın altından belirgin şekilde yukarıda.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return ListView(
      physics: _signing
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl +
            safeBottom +
            (bottomInset > 0
                ? bottomInset + AppSpacing.lg
                : AppSpacing.xxl + AppSpacing.lg),
      ),
      children: [
        // Göz alıcı bir üst başlık kartı — Devreye Alma ile aynı tasarım dili.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.brand,
                AppColors.brand.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.build_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dijital Servis Defteri',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sahada yaptığınız bakımı kaydedin',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        PremiumFormSection(
          title: 'Saha Bilgileri',
          children: [
            PremiumField(
              controller: _siteName,
              label: 'Bina / Tesis Adı',
              icon: Icons.location_on_outlined,
            ),
            PremiumField(
              controller: _systemDescription,
              label: 'Sistem Açıklaması (opsiyonel)',
              icon: Icons.memory_outlined,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumFormSection(
          title: 'Yapılan İşlem',
          children: [
            PremiumField(
              controller: _notes,
              label: 'Neler yapıldı, nelere dikkat edilmeli?',
              icon: Icons.edit_note_outlined,
              minLines: 3,
              maxLines: null,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Müşteri İmzası',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  Text(
                    '(opsiyonel)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SignaturePad(
                key: _signatureKey,
                onChanged: (_) {},
                onDrawingChanged: (drawing) {
                  if (_signing != drawing) setState(() => _signing = drawing);
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _signatureKey.currentState?.clear(),
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('Temizle'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Kaydet',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}
