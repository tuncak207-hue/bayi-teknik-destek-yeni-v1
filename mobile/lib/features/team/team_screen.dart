import 'package:flutter/material.dart';
import '../../core/widgets/design_system.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';

/// Çoklu kullanıcılı bayi hesabı: firma sahibi, aynı firma adı altında
/// ek teknisyen hesapları oluşturup yönetebilir — her teknisyen kendi
/// e-posta/şifresiyle ayrı giriş yapar.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/users/me/team');
      setState(() {
        _members = res.data;
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message'] ?? 'Ekip listesi alınamadı.')),
        );
      }
    }
  }

  Future<void> _remove(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ekip Üyesini Kaldır'),
        content: const Text('Bu kullanıcı hesabı kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dio.delete('/users/me/team/$id');
    _load();
  }

  Future<void> _openAddSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddTeamMemberSheet(),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: const AppPageHeader(title: 'Ekip Üyelerim'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Üye Ekle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? AppEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Henüz ekip üyeniz yok',
                  description: 'Firmanızdaki teknisyenler için ayrı hesaplar oluşturup uygulamayı birlikte kullanabilirsiniz.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _members.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
                        child: Text(
                          'Ekip Üyelerim',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navy, letterSpacing: -0.6, height: 1.1),
                        ),
                      );
                    }
                    final m = _members[index - 1];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.navy, Color(0xFF1D3A56)]),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (m['firstName'] as String? ?? '?').characters.first.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        title: Text('${m['firstName']} ${m['lastName']}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, letterSpacing: -0.1)),
                        subtitle: Text(m['email'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _remove(m['id']),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _AddTeamMemberSheet extends StatefulWidget {
  const _AddTeamMemberSheet();

  @override
  State<_AddTeamMemberSheet> createState() => _AddTeamMemberSheetState();
}

class _AddTeamMemberSheetState extends State<_AddTeamMemberSheet> {
  final Dio _dio = ApiClient().dio;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if ([_firstName, _lastName, _email, _password].any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'Tüm alanları doldurun.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _dio.post('/users/me/team', data: {
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
      });
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message'] ?? 'Üye eklenemedi.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Yeni Ekip Üyesi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(_error!, style: const TextStyle(color: AppColors.brand)),
            ),
          TextField(controller: _firstName, decoration: const InputDecoration(labelText: 'Ad')),
          const SizedBox(height: AppSpacing.xs),
          TextField(controller: _lastName, decoration: const InputDecoration(labelText: 'Soyad')),
          const SizedBox(height: AppSpacing.xs),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-posta')),
          const SizedBox(height: AppSpacing.xs),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre')),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}
