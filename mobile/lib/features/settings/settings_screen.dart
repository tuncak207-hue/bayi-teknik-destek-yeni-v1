import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/design_system.dart';
import '../../core/auth/biometric_service.dart';

const Map<String, String> _kNotificationTypeLabels = {
  'new_message': 'Yeni mesaj',
  'group_message': 'Grup mesajı',
  'announcement': 'Duyurular',
  'appointment_status_changed': 'Randevu durumu',
  'new_document': 'Yeni doküman',
  'ticket_created': 'Teknik destek kaydı',
  'ticket_status_changed': 'Teknik destek durumu',
  'emergency_ticket': 'Acil teknik destek',
};

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Dio _dio = ApiClient().dio;
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _dio.get('/users/me');
    setState(() {
      _profile = res.data;
      _loading = false;
    });
  }

  bool _prefFor(String type) {
    final prefs = (_profile?['notificationPreferences'] as Map?) ?? {};
    return prefs[type] != false; // eksikse varsayılan açık
  }

  Future<void> _setPref(String type, bool value) async {
    final prefs = Map<String, dynamic>.from((_profile?['notificationPreferences'] as Map?) ?? {});
    prefs[type] = value;
    setState(() => _profile!['notificationPreferences'] = prefs);
    await _dio.patch('/users/me/notification-preferences', data: prefs);
  }

  Future<void> _setQuietHours({bool? enabled, String? start, String? end}) async {
    final newEnabled = enabled ?? _profile?['quietHoursEnabled'] == true;
    final newStart = start ?? _profile?['quietHoursStart'] ?? '22:00';
    final newEnd = end ?? _profile?['quietHoursEnd'] ?? '07:00';
    setState(() {
      _profile!['quietHoursEnabled'] = newEnabled;
      _profile!['quietHoursStart'] = newStart;
      _profile!['quietHoursEnd'] = newEnd;
    });
    await _dio.patch('/users/me/quiet-hours', data: {'enabled': newEnabled, 'start': newStart, 'end': newEnd});
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? (_profile?['quietHoursStart'] ?? '22:00') : (_profile?['quietHoursEnd'] ?? '07:00');
    final parts = (current as String).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null) return;
    final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (isStart) {
      _setQuietHours(start: formatted);
    } else {
      _setQuietHours(end: formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppPageHeader(title: 'Ayarlar'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const _SectionTitle('Güvenlik'),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: AppColors.divider)),
                  elevation: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: ThemeController().biometricLockEnabled,
                    builder: (context, enabled, _) => SwitchListTile(
                      title: const Text('Parmak İzi ile Açılış Kilidi'),
                      subtitle: const Text('Uygulama her açıldığında biyometrik onay istenir'),
                      value: enabled,
                      onChanged: (v) async {
                        if (v) {
                          final available = await BiometricService().isAvailable();
                          if (!available) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Bu cihazda parmak izi/yüz tanıma desteklenmiyor.')),
                              );
                            }
                            return;
                          }
                          // Etkinleştirirken hemen bir kez doğrulama isteyip
                          // gerçekten çalıştığından emin oluyoruz.
                          final confirmed = await BiometricService().authenticate();
                          if (!confirmed) return;
                        }
                        ThemeController().setBiometricLockEnabled(v);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('Yazı Boyutu'),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: AppColors.divider)),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      children: [
                        ValueListenableBuilder<double>(
                          valueListenable: ThemeController().fontScale,
                          builder: (context, scale, _) => Column(
                            children: [
                              Text('Örnek Metin', style: TextStyle(fontSize: 16 * scale)),
                              Slider(
                                value: scale,
                                min: 0.85,
                                max: 1.3,
                                divisions: 3,
                                label: scale <= 0.9
                                    ? 'Küçük'
                                    : scale <= 1.05
                                        ? 'Normal'
                                        : scale <= 1.2
                                            ? 'Büyük'
                                            : 'Çok Büyük',
                                onChanged: (v) => ThemeController().setFontScale(v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('Sessiz Saatler'),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: AppColors.divider)),
                  elevation: 0,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Sessiz Saatleri Etkinleştir'),
                        subtitle: const Text('Belirlediğiniz saat aralığında bildirim gelmez'),
                        value: _profile?['quietHoursEnabled'] == true,
                        onChanged: (v) => _setQuietHours(enabled: v),
                      ),
                      if (_profile?['quietHoursEnabled'] == true) ...[
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Başlangıç'),
                          trailing: Text(
                            _profile?['quietHoursStart'] ?? '22:00',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy),
                          ),
                          onTap: () => _pickTime(true),
                        ),
                        ListTile(
                          title: const Text('Bitiş'),
                          trailing: Text(
                            _profile?['quietHoursEnd'] ?? '07:00',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy),
                          ),
                          onTap: () => _pickTime(false),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('Bildirim Tercihleri'),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: AppColors.divider)),
                  elevation: 0,
                  child: Column(
                    children: _kNotificationTypeLabels.entries
                        .map((e) => SwitchListTile(
                              title: Text(e.value),
                              value: _prefFor(e.key),
                              onChanged: (v) => _setPref(e.key, v),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Colors.grey.shade500, letterSpacing: 0.6),
      ),
    );
  }
}
