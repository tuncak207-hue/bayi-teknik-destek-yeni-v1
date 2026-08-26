import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/current_user.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/premium_form_widgets.dart';
import '../../core/widgets/signature_pad.dart';
import '../../core/widgets/design_system.dart';
import '../../core/pdf/document_pdf_exporter.dart';

class CommissioningListScreen extends StatefulWidget {
  const CommissioningListScreen({super.key});

  @override
  State<CommissioningListScreen> createState() => _CommissioningListScreenState();
}

class _CommissioningListScreenState extends State<CommissioningListScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/commissioning/reports');
    setState(() {
      _reports = res.data;
      _loading = false;
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CommissioningFormScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openDetail(dynamic report) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CommissioningFormScreen(existingReport: report)),
    );
    if (updated == true) _load();
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
      floatingActionButton: StandardFab(label: 'Yeni Rapor', onPressed: _openCreate),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Devreye Alma',
                    style: AppText.screenTitle,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${_reports.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          children: [
                            const SizedBox(height: 72),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                              child: StandardCard(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                                child: const AppEmptyState(
                                  icon: Icons.checklist_outlined,
                                  title: 'Henüz bir devreye alma raporu yok',
                                  description: 'Sağ alttaki butondan yeni bir rapor oluşturabilirsiniz.',
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: CustomScrollView(
                          slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final r = _reports[index];
                              final items = (r['items'] as List?) ?? [];
                              final checkedCount = items.where((i) => i['checked'] == true).length;
                              final total = items.isEmpty ? 1 : items.length;
                              final progress = checkedCount / total;
                              final isComplete = r['completedAt'] != null || checkedCount == items.length;

                              return StandardCard(
                                onTap: () => _openDetail(r),
                                padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                StatusBadge(
                                  label: isComplete ? 'Tamamlandı' : 'Devam Ediyor',
                                  tone: isComplete ? AppStatusTone.success : AppStatusTone.pending,
                                ),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 3,
                                        backgroundColor: const Color(0xFFEFF1F4),
                                        valueColor: AlwaysStoppedAnimation(isComplete ? Colors.green : AppColors.brand),
                                      ),
                                      Icon(isComplete ? Icons.check : null, size: 13, color: Colors.green),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              r['siteName'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${r['panelBrand']} ${r['panelModel']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                CardFooterMeta(icon: Icons.checklist_rtl, label: '$checkedCount/${items.length}'),
                                const Spacer(),
                                Text(_formatDate(r['createdAt']), style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400)),
                              ],
                            ),
                          ],
                        ),
                      );
                            },
                            childCount: _reports.length,
                          ),
                        ),
                      ),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommissioningFormScreen extends StatefulWidget {
  final dynamic existingReport;
  const CommissioningFormScreen({super.key, this.existingReport});

  @override
  State<CommissioningFormScreen> createState() => _CommissioningFormScreenState();
}

class _CommissioningFormScreenState extends State<CommissioningFormScreen> {
  final Dio _dio = ApiClient().dio;
  late final _siteNameController = TextEditingController(text: widget.existingReport?['siteName'] ?? '');
  late final _brandController = TextEditingController(text: widget.existingReport?['panelBrand'] ?? '');
  late final _modelController = TextEditingController(text: widget.existingReport?['panelModel'] ?? '');
  late final _notesController = TextEditingController(text: widget.existingReport?['notes'] ?? '');
  late final _customerController = TextEditingController(text: widget.existingReport?['customerName'] ?? '');
  final _signatureKey = GlobalKey<SignaturePadState>();
  List<Map<String, dynamic>> _items = [];
  bool _loadingTemplate = true;
  bool _submitting = false;
  bool _exporting = false;

  bool get _isEditing => widget.existingReport != null;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    if (_isEditing) {
      setState(() {
        _items = (widget.existingReport['items'] as List).cast<Map<String, dynamic>>();
        _loadingTemplate = false;
      });
      return;
    }
    final res = await _dio.get('/commissioning/template');
    setState(() {
      _items = (res.data['items'] as List).cast<Map<String, dynamic>>();
      _loadingTemplate = false;
    });
  }

  int get _checkedCount => _items.where((i) => i['checked'] == true).length;

  Future<void> _submit() async {
    if (_siteNameController.text.trim().isEmpty ||
        _brandController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen saha adı, marka ve model bilgilerini girin.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final payload = {
        'siteName': _siteNameController.text.trim(),
        'panelBrand': _brandController.text.trim(),
        'panelModel': _modelController.text.trim(),
        'items': _items,
        'notes': _notesController.text.trim(),
        'customerName': _customerController.text.trim(),
      };

      String reportId;
      if (_isEditing) {
        reportId = widget.existingReport['id'];
        await _dio.patch('/commissioning/reports/$reportId', data: payload);
      } else {
        final res = await _dio.post('/commissioning/reports', data: payload);
        reportId = res.data['id'];
      }

      final padState = _signatureKey.currentState;
      if (padState != null && padState.hasSignature) {
        final bytes = await padState.renderToPng();
        if (bytes != null) {
          final formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes, filename: 'imza.png'),
          });
          await _dio.post('/commissioning/reports/$reportId/signature', data: formData);
        }
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteReport() async {
    if (!_isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Raporu Sil'),
        content: const Text('Bu devreye alma raporunu kalıcı olarak silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dio.delete('/commissioning/reports/${widget.existingReport['id']}');
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _exportPdf({required bool andShare}) async {
    setState(() => _exporting = true);
    try {
      Uint8List? signatureBytes;
      if (_isEditing && widget.existingReport['signatureUrl'] != null) {
        signatureBytes = await DocumentPdfExporter.downloadSignature(
          _dio,
          '/commissioning/reports/${widget.existingReport['id']}/signature-url',
        );
      }
      final file = await DocumentPdfExporter.build(
        documentTitle: 'Devreye Alma Raporu — ${_siteNameController.text}',
        dealerName: '${CurrentUser().firstName} ${CurrentUser().lastName}',
        dealerCompany: '',
        customerName: _customerController.text,
        infoRows: [
          (label: 'Panel', value: '${_brandController.text} ${_modelController.text}'),
        ],
        checklist: _items.map((i) => (label: i['label'] as String, checked: i['checked'] == true)).toList(),
        notes: _notesController.text,
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
    final progress = _items.isEmpty ? 0.0 : _checkedCount / _items.length;
    final hasSavedSignature = _isEditing && widget.existingReport['signatureUrl'] != null;

    final pdfMenu = _exporting
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        : PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'view') _exportPdf(andShare: false);
              if (v == 'share') _exportPdf(andShare: true);
              if (v == 'delete') _deleteReport();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view', child: Text('PDF Görüntüle')),
              const PopupMenuItem(value: 'share', child: Text('PDF Paylaş')),
              const PopupMenuItem(value: 'delete', child: Text('Raporu Sil', style: TextStyle(color: Colors.red))),
            ],
            icon: const Icon(Icons.more_vert),
          );

    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        navigationBar: CupertinoNavigationBar(
          backgroundColor: const Color(0xFFFFFFFF),
          border: null,
          middle: Text(_isEditing ? 'Devreye Alma Raporu' : 'Yeni Devreye Alma Raporu', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          trailing: _isEditing ? pdfMenu : null,
        ),
        child: SafeArea(child: _buildBody(progress, hasSavedSignature)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppPageHeader(
        title: _isEditing ? 'Devreye Alma Raporu' : 'Yeni Devreye Alma Raporu',
        actions: [if (_isEditing) pdfMenu],
      ),
      body: SafeArea(child: _buildBody(progress, hasSavedSignature)),
    );
  }

  Widget _buildBody(double progress, bool hasSavedSignature) {
    return _loadingTemplate
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                PremiumFormSection(
                  title: 'Saha Bilgileri',
                  children: [
                    PremiumField(controller: _siteNameController, label: 'Saha / Bina Adı', icon: Icons.location_on_outlined),
                    PremiumField(controller: _brandController, label: 'Panel Markası', icon: Icons.memory_outlined),
                    PremiumField(controller: _modelController, label: 'Panel Modeli', icon: Icons.tag_outlined),
                    PremiumField(controller: _customerController, label: 'Müşteri Adı (opsiyonel)', icon: Icons.person_outline, isLast: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // İlerleme başlığı — kendi kartı, göz alıcı bir "halka" ilerleme göstergesiyle.
                // Beyaz zeminli premium görünüm — kullanıcı isteği.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 5,
                              backgroundColor: const Color(0xFFEFF1F4),
                              valueColor: AlwaysStoppedAnimation(progress == 1.0 ? Colors.green : AppColors.brand),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: TextStyle(color: progress == 1.0 ? Colors.green.shade700 : AppColors.navy, fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Kontrol Listesi', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 3),
                            Text('$_checkedCount / ${_items.length} madde tamamlandı', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Her kontrol maddesi artık kendi bağımsız kartı — kullanıcı
                // isteği: "kartlar açılsın, tik atayım". Önceden hepsi tek
                // bir liste kutusu içinde sıralı satırlardı.
                ...List.generate(_items.length, (index) {
                  final item = _items[index];
                  final checked = item['checked'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: checked ? Colors.green.withValues(alpha: 0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: checked ? Colors.green.withValues(alpha: 0.25) : Colors.transparent, width: 1.2),
                        boxShadow: checked
                            ? []
                            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _items[index]['checked'] = !checked),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 14),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: checked ? Colors.green.shade600 : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: checked ? Colors.green.shade600 : Colors.grey.shade300, width: 1.6),
                                    boxShadow: checked ? [BoxShadow(color: Colors.green.withValues(alpha: 0.35), blurRadius: 6)] : [],
                                  ),
                                  child: checked ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    item['label'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13.8,
                                      fontWeight: FontWeight.w500,
                                      color: checked ? Colors.grey.shade400 : const Color(0xFF1C1C1E),
                                      decoration: checked ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: AppSpacing.md),
                PremiumFormSection(
                  title: 'Ek Notlar',
                  children: [
                    PremiumField(controller: _notesController, label: 'Sahada dikkat çeken bir durum var mı?', icon: Icons.edit_note_outlined, minLines: 3, maxLines: 6, isLast: true),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 3))],
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Müşteri İmzası', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
                          ),
                          Text('(opsiyonel)', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400)),
                        ],
                      ),
                      if (hasSavedSignature) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                            const SizedBox(width: 4),
                            Text('Bu raporda kayıtlı bir imza var.', style: TextStyle(fontSize: 11.5, color: Colors.green.shade700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Yeniden imza almak isterseniz aşağıya çizin — kaydedince öncekinin yerine geçer.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      SignaturePad(key: _signatureKey, onChanged: (_) {}),
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
                if (_checkedCount < _items.length)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(AppSpacing.radius),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tüm maddeler işaretlenmeden rapor "Tamamlandı" sayılmaz, ama yine de kaydedip sonra devam edebilirsiniz.',
                            style: TextStyle(fontSize: 11.5, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isEditing ? 'Değişiklikleri Kaydet' : 'Raporu Kaydet', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            );
  }
}
