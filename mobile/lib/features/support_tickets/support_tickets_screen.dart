import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/design_system.dart';
import '../../core/events/notification_badge_bus.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _dio.post('/notifications/mark-category-read/support_tickets').then((_) => NotificationBadgeBus.bump());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/support-tickets');
    setState(() {
      _tickets = res.data;
      _loading = false;
    });
  }

  Future<void> _openCreate({required bool isEmergency}) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _CreateTicketScreen(isEmergency: isEmergency)),
    );
    if (created == true) _load();
  }

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'EMERGENCY':
        return AppColors.navy;
      case 'HIGH':
        return Colors.orange;
      default:
        return AppColors.navy;
    }
  }

  String _statusText(String status) {
    const map = {
      'OPEN': 'Açık',
      'IN_PROGRESS': 'İşlemde',
      'RESOLVED': 'Çözüldü',
      'CLOSED': 'Kapatıldı',
      'ESCALATED': 'Yükseltildi',
    };
    return map[status] ?? status;
  }

  AppStatusTone _statusTone(String status) {
    switch (status) {
      case 'RESOLVED':
      case 'CLOSED':
        return AppStatusTone.success;
      case 'IN_PROGRESS':
        return AppStatusTone.inProgress;
      case 'ESCALATED':
        return AppStatusTone.danger;
      default:
        return AppStatusTone.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      floatingActionButton: StandardFab(label: 'Yeni Kayıt', onPressed: () => _openCreate(isEmergency: false)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Teknik Destek',
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
                      '${_tickets.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      onTap: () => _openCreate(isEmergency: true),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.brand, AppColors.brand.withValues(alpha: 0.8)]),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          boxShadow: [BoxShadow(color: AppColors.brand.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadius.sm)),
                              child: const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppLocalizations.of(context)!.screenEmergencySupport, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                  SizedBox(height: 2),
                                  Text(AppLocalizations.of(context)!.oneTapEmergencyRecord, style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_tickets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl),
                      child: StandardCard(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                        child: const AppEmptyState(icon: Icons.build_circle_outlined, title: 'Henüz bir teknik destek kaydınız yok'),
                      ),
                    )
                  else
                    ..._tickets.map((t) {
                      final isEmergency = t['isEmergency'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: StandardCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => _TicketDetailScreen(ticketId: t['id'])),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          border: isEmergency ? Border.all(color: AppColors.navy.withValues(alpha: 0.35), width: 1.5) : null,
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: _priorityColor(t['priority']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                                child: Icon(
                                  isEmergency ? Icons.warning_amber_rounded : Icons.build_outlined,
                                  color: _priorityColor(t['priority']),
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CardHeaderRow(
                                      title: t['productName'] ?? t['description'] ?? '',
                                      trailing: isEmergency ? const StatusBadge(label: 'ACİL', tone: AppStatusTone.danger) : null,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        StatusBadge(label: _statusText(t['status']), tone: _statusTone(t['status'])),
                                        const SizedBox(width: 8),
                                        CardFooterMeta(icon: Icons.schedule_outlined, label: _formatDate(t['createdAt'])),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
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

class _CreateTicketScreen extends StatefulWidget {
  final bool isEmergency;
  const _CreateTicketScreen({required this.isEmergency});

  @override
  State<_CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<_CreateTicketScreen> {
  final Dio _dio = ApiClient().dio;
  final _productNameController = TextEditingController();
  final _productModelController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _pickedPhotoPath;
  String? _pickedPhotoName;
  bool _submitting = false;

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(AppLocalizations.of(context)!.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(AppLocalizations.of(context)!.chooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final picked = await ImagePicker().pickImage(source: choice, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _pickedPhotoPath = picked.path;
        _pickedPhotoName = picked.name;
      });
    }
  }

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseDescribeIssue)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await _dio.post('/support-tickets', data: {
        'productName': _productNameController.text.trim(),
        'productModel': _productModelController.text.trim(),
        'serialNumber': _serialNumberController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'isEmergency': widget.isEmergency,
      });

      if (_pickedPhotoPath != null) {
        final ticketId = res.data['id'];
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(_pickedPhotoPath!, filename: _pickedPhotoName),
        });
        await _dio.post('/support-tickets/$ticketId/attachment', data: formData);
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
        navigationBar: CupertinoNavigationBar(
          backgroundColor: const Color(0xFFFFFFFF),
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel, style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 16)),
          ),
          middle: Text(widget.isEmergency ? AppLocalizations.of(context)!.screenEmergencySupport : AppLocalizations.of(context)!.screenNewSupportTicket, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.navy)),
        ),
        child: SafeArea(child: _buildForm()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppPageHeader(title: widget.isEmergency ? AppLocalizations.of(context)!.screenEmergencySupport : AppLocalizations.of(context)!.screenNewSupportTicket),
      body: SafeArea(child: _buildForm()),
    );
  }

  Widget _buildForm() {
    return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (widget.isEmergency)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.navy, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Bu kayıt ACİL olarak işaretlenip mühendis ve yöneticilere anında bildirilecek.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.navy),
                    ),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _productNameController,
            decoration: const InputDecoration(labelText: 'Ürün Adı', hintText: 'Örn: MA8000 Yangın Alarm Paneli'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _productModelController,
            decoration: const InputDecoration(labelText: 'Model (opsiyonel)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _serialNumberController,
            decoration: const InputDecoration(labelText: 'Seri Numarası (opsiyonel)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Konum (opsiyonel)', hintText: 'Örn: İstanbul, Kadıköy'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Sorunu Açıklayın'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: Icon(_pickedPhotoPath != null ? Icons.check_circle_outline : Icons.camera_alt_outlined),
            label: Text(_pickedPhotoPath != null ? 'Fotoğraf Eklendi' : 'Fotoğraf Ekle (opsiyonel)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isEmergency ? AppColors.navy : AppColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.isEmergency ? 'Acil Kaydı Gönder' : 'Kaydı Gönder', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
    );
  }
}

/// Kayıt detayı — Faz 2: SLA geri sayımını canlı gösterir.
class _TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const _TicketDetailScreen({required this.ticketId});

  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  final Dio _dio = ApiClient().dio;
  dynamic _ticket;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _dio.get('/support-tickets/${widget.ticketId}');
    setState(() {
      _ticket = res.data;
      _loading = false;
    });
  }

  String _formatRemaining(int? minutes) {
    if (minutes == null) return '';
    if (minutes < 0) return 'Süre doldu';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) return '$hours sa $mins dk kaldı';
    return '$mins dk kaldı';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = _ticket;
    final slaStatus = t['slaStatus'] ?? {};
    final isEmergency = t['isEmergency'] == true;
    final escalationLevel = t['escalationLevel'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppPageHeader(title: AppLocalizations.of(context)!.screenRecordDetail),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (isEmergency)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.xl)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.navy),
                    SizedBox(width: 6),
                    Text(AppLocalizations.of(context)!.emergencyRecordShort, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.navy)),
                  ],
                ),
              ),
            if (escalationLevel > 0)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu kayıt yükseltildi (eskalasyon seviye $escalationLevel) — yanıt/çözüm süresi aşıldığı için üst yetkiliye bildirildi.',
                        style: const TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            // SLA geri sayım kartı
            if (slaStatus['resolutionRemainingMinutes'] != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: slaStatus['resolutionBreached'] == true ? AppColors.navy.withValues(alpha: 0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.subtle,
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: slaStatus['resolutionBreached'] == true ? AppColors.navy : AppColors.brand),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context)!.resolutionTimeSla, style: TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w600)),
                          Text(
                            _formatRemaining(slaStatus['resolutionRemainingMinutes']),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: slaStatus['resolutionBreached'] == true ? AppColors.navy : AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.subtle,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['productName'] ?? 'Ürün belirtilmedi', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
                  if ((t['productModel'] ?? '').toString().isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(AppLocalizations.of(context)!.modelLabel(t['productModel']), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                  if ((t['serialNumber'] ?? '').toString().isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(AppLocalizations.of(context)!.serialNoLabel(t['serialNumber']), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                  if ((t['location'] ?? '').toString().isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(AppLocalizations.of(context)!.locationLabel(t['location']), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                  const Divider(height: 24),
                  Text(t['description'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _BeforeAfterPhotoSection(ticketId: widget.ticketId),
            const SizedBox(height: AppSpacing.md),
            _MeasurementSection(ticketId: widget.ticketId, serialNumber: t['serialNumber']),
            const SizedBox(height: AppSpacing.md),
            _SparePartSection(ticketId: widget.ticketId, ticket: t),
            const SizedBox(height: AppSpacing.md),
            _CostSection(ticketId: widget.ticketId),
            const SizedBox(height: AppSpacing.md),
            _KnowledgeBaseSection(ticket: t),
          ],
        ),
      ),
    );
  }
}

/// Önce/Sonra Fotoğraf Karşılaştırma (Faz 3, #7) — saha işlemi öncesi ve
/// sonrası fotoğraflar aynı kayıt altında gruplanıp yan yana gösterilir.
class _BeforeAfterPhotoSection extends StatefulWidget {
  final String ticketId;
  const _BeforeAfterPhotoSection({required this.ticketId});

  @override
  State<_BeforeAfterPhotoSection> createState() => _BeforeAfterPhotoSectionState();
}

class _BeforeAfterPhotoSectionState extends State<_BeforeAfterPhotoSection> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _before = [];
  List<dynamic> _after = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _dio.get('/support-tickets/${widget.ticketId}/photos');
    setState(() {
      _before = res.data['before'];
      _after = res.data['after'];
    });
  }

  Future<void> _addPhoto(String type) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(picked.path, filename: picked.name),
      });
      await _dio.post('/support-tickets/${widget.ticketId}/photos/$type', data: formData);
      await _load();
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _photoGrid(List<dynamic> photos, String label, String type, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...photos.map((p) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.network(p['signedUrl'], width: 64, height: 64, fit: BoxFit.cover),
                  )),
              InkWell(
                onTap: _uploading ? null : () => _addPhoto(type),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Icon(Icons.add_a_photo_outlined, size: 20, color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.beforeAfterPhoto, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _photoGrid(_before, 'ÖNCE', 'BEFORE', Colors.orange),
              const SizedBox(width: 12),
              _photoGrid(_after, 'SONRA', 'AFTER', Colors.green),
            ],
          ),
        ],
      ),
    );
  }
}

/// Teknik Ölçüm Sistemi (Faz 3, #8) — mühendis saha sırasında ölçüm
/// girer, limit dışı değerlerde anlık uyarı gösterilir.
class _MeasurementSection extends StatefulWidget {
  final String ticketId;
  final String? serialNumber;
  const _MeasurementSection({required this.ticketId, this.serialNumber});

  @override
  State<_MeasurementSection> createState() => _MeasurementSectionState();
}

class _MeasurementSectionState extends State<_MeasurementSection> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _measurements = [];
  List<dynamic> _types = [];
  String? _selectedTypeId;
  final _valueController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _dio.get('/support-tickets/${widget.ticketId}/measurements'),
      _dio.get('/support-tickets/measurement-types'),
    ]);
    setState(() {
      _measurements = results[0].data;
      _types = results[1].data;
    });
  }

  Future<void> _submit() async {
    final value = double.tryParse(_valueController.text.trim());
    if (_selectedTypeId == null || value == null) return;
    setState(() => _submitting = true);
    try {
      final res = await _dio.post('/support-tickets/${widget.ticketId}/measurements', data: {
        'measurementTypeId': _selectedTypeId,
        'value': value,
      });
      _valueController.clear();
      await _load();
      if (res.data['isOutOfRange'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.valueOutOfRange), backgroundColor: AppColors.navy),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.technicalMeasurements, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
          const SizedBox(height: 12),
          if (_types.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTypeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ölçüm Türü', isDense: true),
                    items: _types
                        .map<DropdownMenuItem<String>>((t) => DropdownMenuItem(value: t['id'], child: Text('${t['name']} (${t['unit']})', overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTypeId = v),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Değer', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add),
                ),
              ],
            ),
            SizedBox(height: 12),
          ] else
            Text(AppLocalizations.of(context)!.noMeasurementTypeYet, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          if (_measurements.isNotEmpty) ...[
            const Divider(height: 20),
            ..._measurements.map((m) {
              final outOfRange = m['isOutOfRange'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(outOfRange ? Icons.warning_amber_rounded : Icons.check_circle_outline, size: 16, color: outOfRange ? AppColors.navy : Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${m['measurementType']['name']}: ${m['value']} ${m['measurementType']['unit']}',
                        style: TextStyle(fontSize: 12.5, color: outOfRange ? AppColors.navy : AppColors.navy, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Teknik Destek → Yedek Parça Talebi (Faz 4, #6) — ürün/model/seri no
/// kayıttan otomatik geliyor, kullanıcı sadece parça bilgisini giriyor.
class _SparePartSection extends StatefulWidget {
  final String ticketId;
  final dynamic ticket;
  const _SparePartSection({required this.ticketId, required this.ticket});

  @override
  State<_SparePartSection> createState() => _SparePartSectionState();
}

class _SparePartSectionState extends State<_SparePartSection> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _dio.get('/support-tickets/${widget.ticketId}/spare-part-requests');
    setState(() => _requests = res.data);
  }

  Future<void> _openRequestForm() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SparePartRequestSheet(ticket: widget.ticket),
    );
    if (result != null) {
      await _dio.post('/support-tickets/${widget.ticketId}/spare-part-requests', data: result);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(AppLocalizations.of(context)!.sparePartRequests, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
              ),
              TextButton.icon(
                onPressed: _openRequestForm,
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppLocalizations.of(context)!.createRequest, style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
          if (_requests.isEmpty)
            Text(AppLocalizations.of(context)!.emptyPartRequests, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
          else
            ..._requests.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.build_circle_outlined, size: 16, color: AppColors.brand),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${r['partName']} × ${r['quantity']}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _SparePartRequestSheet extends StatefulWidget {
  final dynamic ticket;
  const _SparePartRequestSheet({required this.ticket});

  @override
  State<_SparePartRequestSheet> createState() => _SparePartRequestSheetState();
}

class _SparePartRequestSheetState extends State<_SparePartRequestSheet> {
  final _partCodeController = TextEditingController();
  final _partNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppLocalizations.of(context)!.sparePartRequest, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          // Ürün/model/seri no otomatik aktarılıyor — kullanıcı tekrar girmiyor.
          Text(
            '${widget.ticket['productName'] ?? ''} ${widget.ticket['productModel'] ?? ''} · SN: ${widget.ticket['serialNumber'] ?? '—'}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          TextField(controller: _partCodeController, decoration: const InputDecoration(labelText: 'Parça Kodu (opsiyonel)')),
          const SizedBox(height: 12),
          TextField(controller: _partNameController, decoration: const InputDecoration(labelText: 'Parça Adı')),
          const SizedBox(height: 12),
          TextField(controller: _quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Miktar')),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_partNameController.text.trim().isEmpty) return;
              Navigator.pop(context, {
                'partCode': _partCodeController.text.trim(),
                'partName': _partNameController.text.trim(),
                'quantity': int.tryParse(_quantityController.text.trim()) ?? 1,
              });
            },
            child: Text(AppLocalizations.of(context)!.submitRequest),
          ),
        ],
      ),
    );
  }
}

/// Teknik Destek Maliyet Analizi (Faz 4, #4) — mühendis çalışma süresi,
/// saha ziyareti, yol, konaklama, yedek parça, işçilik gibi kalemler.
class _CostSection extends StatefulWidget {
  final String ticketId;
  const _CostSection({required this.ticketId});

  @override
  State<_CostSection> createState() => _CostSectionState();
}

class _CostSectionState extends State<_CostSection> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _costs = [];

  static const _categoryLabels = {
    'ENGINEER_TIME': 'Mühendis Çalışma Süresi',
    'SITE_VISIT': 'Saha Ziyareti',
    'TRAVEL': 'Yol',
    'ACCOMMODATION': 'Konaklama',
    'SPARE_PART': 'Yedek Parça',
    'LABOR': 'İşçilik',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _dio.get('/support-tickets/${widget.ticketId}/costs');
    setState(() => _costs = res.data);
  }

  Future<void> _openCostForm() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CostEntrySheet(),
    );
    if (result != null) {
      await _dio.post('/support-tickets/${widget.ticketId}/costs', data: result);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _costs.fold<double>(0, (sum, c) => sum + (c['amount'] as num).toDouble());
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(AppLocalizations.of(context)!.costItems, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
              ),
              TextButton.icon(
                onPressed: _openCostForm,
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppLocalizations.of(context)!.addItem, style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
          if (_costs.isEmpty)
            Text(AppLocalizations.of(context)!.emptyCosts, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
          else ...[
            ..._costs.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(_categoryLabels[c['category']] ?? c['category'], style: const TextStyle(fontSize: 12.5))),
                      Text('${c['amount']} ₺', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.brand)),
                    ],
                  ),
                )),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)!.total, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text('${total.toStringAsFixed(2)} ₺', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CostEntrySheet extends StatefulWidget {
  const _CostEntrySheet();

  @override
  State<_CostEntrySheet> createState() => _CostEntrySheetState();
}

class _CostEntrySheetState extends State<_CostEntrySheet> {
  String _category = 'ENGINEER_TIME';
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const _categories = {
    'ENGINEER_TIME': 'Mühendis Çalışma Süresi',
    'SITE_VISIT': 'Saha Ziyareti',
    'TRAVEL': 'Yol',
    'ACCOMMODATION': 'Konaklama',
    'SPARE_PART': 'Yedek Parça',
    'LABOR': 'İşçilik',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppLocalizations.of(context)!.addCostItem, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: _categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tutar (₺)'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Açıklama (opsiyonel)')),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(_amountController.text.trim());
              if (amount == null) return;
              Navigator.pop(context, {
                'category': _category,
                'amount': amount,
                'description': _descriptionController.text.trim(),
              });
            },
            child: Text(AppLocalizations.of(context)!.add),
          ),
        ],
      ),
    );
  }
}

/// Teknik Bilgi Hafızası (Faz 8, #20) — mühendis saha tecrübesini
/// (problem/çözüm) kaydeder, AI gelecekte benzer sorularda bu bilgiyi
/// otomatik olarak referans alır.
class _KnowledgeBaseSection extends StatefulWidget {
  final dynamic ticket;
  const _KnowledgeBaseSection({required this.ticket});

  @override
  State<_KnowledgeBaseSection> createState() => _KnowledgeBaseSectionState();
}

class _KnowledgeBaseSectionState extends State<_KnowledgeBaseSection> {
  final Dio _dio = ApiClient().dio;
  bool _saved = false;
  bool _submitting = false;

  Future<void> _openForm() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _KnowledgeEntrySheet(ticket: widget.ticket),
    );
    if (result == null) return;
    setState(() => _submitting = true);
    try {
      await _dio.post('/knowledge-base', data: result);
      setState(() => _saved = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: const Icon(Icons.psychology_outlined, color: AppColors.navy, size: 19),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.addToKnowledgeMemory, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy)),
                SizedBox(height: 2),
                Text(AppLocalizations.of(context)!.saveCaseKnowledgeHint, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
              ],
            ),
          ),
          _saved
              ? const Icon(Icons.check_circle, color: Colors.green)
              : TextButton(
                  onPressed: _submitting ? null : _openForm,
                  child: _submitting
                      ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(AppLocalizations.of(context)!.add),
                ),
        ],
      ),
    );
  }
}

class _KnowledgeEntrySheet extends StatefulWidget {
  final dynamic ticket;
  const _KnowledgeEntrySheet({required this.ticket});

  @override
  State<_KnowledgeEntrySheet> createState() => _KnowledgeEntrySheetState();
}

class _KnowledgeEntrySheetState extends State<_KnowledgeEntrySheet> {
  final _problemController = TextEditingController();
  final _solutionController = TextEditingController();
  final _errorCodeController = TextEditingController();
  final _partUsedController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _problemController.text = widget.ticket['description'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppLocalizations.of(context)!.saveFieldExperience, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            '${widget.ticket['productName'] ?? ''} ${widget.ticket['productModel'] ?? ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          TextField(controller: _problemController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Problem')),
          const SizedBox(height: 12),
          TextField(controller: _solutionController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Çözüm')),
          const SizedBox(height: 12),
          TextField(controller: _errorCodeController, decoration: const InputDecoration(labelText: 'Hata Kodu (opsiyonel)')),
          const SizedBox(height: 12),
          TextField(controller: _partUsedController, decoration: const InputDecoration(labelText: 'Kullanılan Parça (opsiyonel)')),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_problemController.text.trim().isEmpty || _solutionController.text.trim().isEmpty) return;
              Navigator.pop(context, {
                'problem': _problemController.text.trim(),
                'solution': _solutionController.text.trim(),
                'productName': widget.ticket['productName'] ?? '',
                'productModel': widget.ticket['productModel'] ?? '',
                'errorCode': _errorCodeController.text.trim(),
                'partUsed': _partUsedController.text.trim(),
              });
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }
}
