import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/design_system.dart';
import '../../core/events/notification_badge_bus.dart';
import '../../core/widgets/province_district_picker.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _appointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _dio.post('/notifications/mark-category-read/appointments').then((_) => NotificationBadgeBus.bump());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/appointments');
    setState(() {
      _appointments = res.data;
      _loading = false;
    });
  }

  Future<void> _cancel(dynamic appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Randevuyu İptal Et'),
        content: Text('"${appointment['subject']}" randevusunu iptal etmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('İptal Et', style: TextStyle(color: AppColors.navy)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dio.delete('/appointments/${appointment['id']}');
    _load();
  }

  Future<void> _delete(dynamic appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Randevuyu Sil'),
        content: Text('"${appointment['subject']}" randevusu kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil', style: TextStyle(color: AppColors.navy)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dio.delete('/appointments/${appointment['id']}/own-delete');
    _load();
  }

  /// Belirli bir tarih aralığında tüm saatleri dolu olan günleri çeker —
  /// takvimde bu günler seçilemez/gri gösterilir (kullanıcı isteği:
  /// "dolu olan gün ve saatler etkisiz olsun").
  Future<Set<String>> _loadFullyBookedDates() async {
    final from = DateTime.now();
    final to = DateTime.now().add(const Duration(days: 90));
    final fmt = (DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      final res = await _dio.get('/appointments/fully-booked-dates', queryParameters: {'from': fmt(from), 'to': fmt(to)});
      return Set<String>.from(res.data);
    } catch (_) {
      return {};
    }
  }

  Future<void> _editDateTime(dynamic appointment) async {
    final currentStart = DateTime.tryParse(appointment['preferredStart'] ?? '') ?? DateTime.now();
    final fullyBooked = await _loadFullyBookedDates();
    if (!mounted) return;
    final fmt = (DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final date = await showDatePicker(
      context: context,
      initialDate: currentStart.isAfter(DateTime.now()) ? currentStart : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      // Tüm saatleri dolu olan günler takvimde seçilemez (pasif) gösterilir.
      selectableDayPredicate: (d) => !fullyBooked.contains(fmt(d)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentStart.hour, minute: currentStart.minute),
    );
    if (time == null) return;

    final newDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    try {
      await _dio.patch('/appointments/${appointment['id']}/own', data: {
        'preferredStart': newDateTime.toIso8601String(),
      });
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Randevu tarihi güncellendi.')),
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu saat az önce başka bir bayi tarafından alındı. Lütfen tekrar deneyin.')),
        );
      }
    }
  }

  Future<void> _openCreateSheet() async {
    final route = Platform.isIOS
        ? CupertinoPageRoute<bool>(builder: (_) => const _CreateAppointmentSheet(), fullscreenDialog: true)
        : MaterialPageRoute<bool>(builder: (_) => const _CreateAppointmentSheet(), fullscreenDialog: true);
    final created = await Navigator.push<bool>(context, route);
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: StandardFab(label: 'Randevu Al', onPressed: _openCreateSheet),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Randevularım',
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
                      '${_appointments.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _appointments.isEmpty
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
                                  icon: Icons.calendar_month_outlined,
                                  title: 'Henüz bir randevunuz yok',
                                  description: 'Teknik destek almak için ilk randevunuzu oluşturun.',
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: _appointments.length,
                          itemBuilder: (context, index) {
                      final a = _appointments[index];
                      return _AppointmentCard(
                        appointment: a,
                        onCancel: () => _cancel(a),
                        onDelete: () => _delete(a),
                        onEdit: () => _editDateTime(a),
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

class _AppointmentCard extends StatelessWidget {
  final dynamic appointment;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _AppointmentCard({required this.appointment, required this.onCancel, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final status = appointment['status'] as String;
    final type = appointment['type'] as String;
    final start = DateTime.tryParse(appointment['preferredStart'] ?? '');
    final isCancelled = status == 'CANCELLED';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: StandardCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.navy.withValues(alpha: 0.10), AppColors.brand.withValues(alpha: 0.10)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    type == 'ON_SITE' ? Icons.location_on_outlined : Icons.call_outlined,
                    size: 18,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    appointment['subject'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.navy, letterSpacing: -0.2),
                  ),
                ),
                _statusPill(status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(type == 'ON_SITE' ? 'Sahada Ziyaret' : 'Telefon/Görüntülü Destek',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
              ],
            ),
            if (start != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${start.day.toString().padLeft(2, '0')}.${start.month.toString().padLeft(2, '0')}.${start.year}  ·  '
                    '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 13, color: AppColors.navy, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            if ((appointment['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(appointment['description'], style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
            if ((appointment['province'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    [appointment['district'], appointment['province']].where((s) => s != null && s.toString().isNotEmpty).join(', '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
            if ((appointment['adminNote'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(child: Text(appointment['adminNote'], style: const TextStyle(fontSize: 12.5))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isCancelled) ...[
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_calendar_outlined, size: 15, color: AppColors.navy),
                    label: const Text('Düzenle', style: TextStyle(color: AppColors.navy)),
                  ),
                  if (status == 'PENDING')
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, size: 15, color: Colors.orange),
                      label: const Text('İptal Et', style: TextStyle(color: Colors.orange)),
                    ),
                ],
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.navy),
                  label: const Text('Sil', style: TextStyle(color: AppColors.navy)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final map = <String, (String, Color, IconData)>{
      'PENDING': ('Onay Bekliyor', Colors.orange, Icons.hourglass_empty),
      'CONFIRMED': ('Onaylandı', Colors.green, Icons.check_circle_outline),
      'CANCELLED': ('İptal Edildi', Colors.grey, Icons.cancel_outlined),
      'COMPLETED': ('Tamamlandı', Colors.blue, Icons.task_alt),
    };
    final entry = map[status] ?? (status, Colors.grey, Icons.circle);
    return StatusPill(label: entry.$1, color: entry.$2, icon: entry.$3);
  }
}

class _CreateAppointmentSheet extends StatefulWidget {
  const _CreateAppointmentSheet();

  @override
  State<_CreateAppointmentSheet> createState() => _CreateAppointmentSheetState();
}

class _CreateAppointmentSheetState extends State<_CreateAppointmentSheet> {
  final Dio _dio = ApiClient().dio;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'REMOTE';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _province;
  String? _district;
  Set<String> _fullyBookedDates = {};
  bool _submitting = false;

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    if (_fullyBookedDates.isEmpty) {
      final from = DateTime.now();
      final to = DateTime.now().add(const Duration(days: 90));
      try {
        final res = await _dio.get('/appointments/fully-booked-dates', queryParameters: {'from': _fmt(from), 'to': _fmt(to)});
        _fullyBookedDates = Set<String>.from(res.data);
      } catch (_) {}
    }
    if (!mounted) return;

    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      selectableDayPredicate: (d) => !_fullyBookedDates.contains(_fmt(d)),
    );
    if (date == null) return;
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
    });
    await _pickTime();
  }

  /// Native saat kadranı — en basit haliyle, hiçbir ekstra kısıtlama
  /// olmadan (kullanıcı isteği: "ilk haline geri al").
  Future<void> _pickTime() async {
    if (_selectedDate == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;
    if (mounted) setState(() => _selectedTime = time);
  }

  Future<void> _submit() async {
    if (_subjectController.text.trim().isEmpty || _selectedDate == null || _selectedTime == null) return;
    setState(() => _submitting = true);
    try {
      final dateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
      await _dio.post('/appointments', data: {
        'type': _type,
        'subject': _subjectController.text.trim(),
        'description': _descriptionController.text.trim(),
        'province': _province,
        'district': _district,
        'preferredStart': dateTime.toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu saat az önce başka bir bayi tarafından alındı. Lütfen başka bir saat seçin.')),
        );
        setState(() => _selectedTime = null);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: Colors.white,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Colors.white,
          border: null,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 16)),
          ),
          middle: const Text('Yeni Randevu Talebi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        child: SafeArea(child: _buildForm()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppPageHeader(title: AppLocalizations.of(context)!.screenNewAppointment),
      body: SafeArea(child: _buildForm()),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20,
      ),
      child: SingleChildScrollView(
        child: StandardCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'REMOTE', label: Text('Telefon/Görüntülü'), icon: Icon(Icons.call_outlined)),
                ButtonSegment(value: 'ON_SITE', label: Text('Sahada Ziyaret'), icon: Icon(Icons.location_on_outlined)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Konu', hintText: 'Örn: MA8000 devreye alma desteği'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Açıklama (opsiyonel)'),
            ),
            const SizedBox(height: 12),
            ProvinceDistrictPicker(
              province: _province,
              district: _district,
              onProvinceChanged: (v) => setState(() => _province = v),
              onDistrictChanged: (v) => setState(() => _district = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _selectedDate == null
                    ? 'Tarih ve Saat Seç'
                    : '${_selectedDate!.day}.${_selectedDate!.month}.${_selectedDate!.year}'
                        '${_selectedTime != null ? '  ${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}' : ''}',
              ),
            ),
            if (_selectedDate != null && _selectedTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time, size: 16),
                  label: const Text('Saati Değiştir'),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Randevu Talebi Gönder'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
