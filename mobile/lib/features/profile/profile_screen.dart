import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';
import '../auth/data/auth_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Dio _dio = ApiClient().dio;
  Map<String, dynamic>? _profile;
  String? _loadError;
  List<dynamic> _badges = [];
  Map<String, dynamic>? _myStats;

  @override
  void initState() {
    super.initState();
    _load();
    _loadBadges();
    _loadMyStats();
  }

  Future<void> _loadMyStats() async {
    try {
      final res = await _dio.get('/stats/me');
      if (mounted) setState(() => _myStats = res.data);
    } catch (_) {
      // İkincil bir bilgi, sessizce yut.
    }
  }

  Future<void> _loadBadges() async {
    try {
      final res = await _dio.get('/stats/me/badges');
      if (mounted) setState(() => _badges = res.data['badges'] ?? []);
    } catch (_) {
      // Rozetler ikincil bir bilgi, sessizce yut.
    }
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get('/users/me');
      if (mounted) setState(() => _profile = res.data);
    } catch (e) {
      // Önceden burada hata yakalama hiç yoktu — istek başarısız olunca
      // _profile hiç dolmuyor, ekran sonsuza kadar yükleniyor görünüyordu.
      if (mounted) {
        setState(() => _loadError = 'Profil yüklenemedi. İnternet bağlantınızı kontrol edip tekrar deneyin.');
      }
    }
  }

  Future<void> _logout() async {
    await AuthRepository().logout();
    if (mounted) context.go('/login');
  }

  String _initials(String? first, String? last) {
    final f = (first != null && first.isNotEmpty) ? first[0] : '';
    final l = (last != null && last.isNotEmpty) ? last[0] : '';
    final result = '$f$l'.toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  Future<void> _openEditProfileDialog() async {
    final firstNameController = TextEditingController(text: _profile!['firstName']);
    final lastNameController = TextEditingController(text: _profile!['lastName']);
    final phoneController = TextEditingController(text: _profile!['phone']);
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            if (firstNameController.text.trim().isEmpty || lastNameController.text.trim().isEmpty) {
              setDialogState(() => error = 'Ad ve soyad boş olamaz.');
              return;
            }
            try {
              await _dio.patch('/users/me', data: {
                'firstName': firstNameController.text.trim(),
                'lastName': lastNameController.text.trim(),
                'phone': phoneController.text.trim(),
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await _load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil güncellendi.')),
                );
              }
            } on DioException catch (e) {
              setDialogState(() => error = e.response?.data?['message'] ?? 'Profil güncellenemedi.');
            }
          }

          return AlertDialog(
            title: const Text('Profili Düzenle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(error!, style: const TextStyle(color: AppColors.navy, fontSize: 13)),
                    ),
                  _ProfileDialogField(controller: firstNameController, label: 'Ad', icon: Icons.person_outline),
                  const SizedBox(height: 10),
                  _ProfileDialogField(controller: lastNameController, label: 'Soyad', icon: Icons.person_outline),
                  const SizedBox(height: 10),
                  _ProfileDialogField(
                    controller: phoneController,
                    label: 'Telefon',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
              ElevatedButton(onPressed: submit, child: const Text('Kaydet')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            if (newController.text.length < 8) {
              setDialogState(() => error = 'Yeni şifre en az 8 karakter olmalı.');
              return;
            }
            if (newController.text != confirmController.text) {
              setDialogState(() => error = 'Yeni şifreler eşleşmiyor.');
              return;
            }
            try {
              await _dio.patch('/users/me/password', data: {
                'currentPassword': currentController.text,
                'newPassword': newController.text,
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Şifreniz güncellendi.')),
                );
              }
            } on DioException catch (e) {
              setDialogState(() => error = e.response?.data?['message'] ?? 'Şifre değiştirilemedi.');
            }
          }

          return AlertDialog(
            title: const Text('Şifre Değiştir'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(error!, style: const TextStyle(color: AppColors.navy, fontSize: 13)),
                    ),
                  TextField(
                    controller: currentController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mevcut Şifre'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Yeni Şifre'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Yeni Şifre (Tekrar)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
              ElevatedButton(onPressed: submit, child: const Text('Kaydet')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Hesabı Sil'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bu işlem geri alınamaz. Hesabınız ve kişisel bilgileriniz silinecek; '
                    'mesajlarınız anonimleştirilecek ve bu oturum kapatılacaktır.',
                    style: TextStyle(fontSize: 13.5),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                onPressed: () async {
                  try {
                    await _dio.delete('/users/me');
                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                  } on DioException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.response?.data?['message'] ?? 'Hesap silinemedi.')),
                    );
                  }
                },
                child: const Text('Hesabımı Sil'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      await AuthRepository().logout();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: const AppPageHeader(title: 'Profil'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.brand, size: 40),
                const SizedBox(height: AppSpacing.sm),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _loadError = null);
                    _load();
                  },
                  child: const Text('Tekrar Dene'),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Oturum artık geçersizse (örn. hesap silindi/veritabanı
                // sıfırlandı), kullanıcı "Tekrar Dene" ile sonsuza kadar
                // aynı hataya takılıp kalabilir — çıkış yapıp yeniden giriş
                // yapabilmesi için buraya da bir yol bırakıyoruz.
                TextButton(
                  onPressed: _logout,
                  child: const Text('Çıkış Yap ve Tekrar Giriş Yap'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Kullanıcı isteği: "profil içeriğinin tasarımını komple değiştir,
    // daha premium, daha sade ve global olmalı" — önceki dekoratif
    // sweep-gradient avatar halkası, arka plan "halo" lekeleri, gradyan
    // metin ve gradyanlı istatistik kartları tamamen kaldırıldı. Yerine
    // düz renkler, ince kenarlıklar ve bol boşluk kullanan; büyük
    // uluslararası SaaS ürünlerinde (Linear, Stripe, Notion) görülen
    // sade/nötr bir dil kullanıldı.
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const AppPageHeader(title: 'Profil'),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: scheme.surfaceContainerHighest,
                      backgroundImage: _profile!['avatarUrl'] != null ? NetworkImage(_profile!['avatarUrl']) : null,
                      child: _profile!['avatarUrl'] == null
                          ? Text(
                              _initials(_profile!['firstName'], _profile!['lastName']),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.navy),
                            )
                          : null,
                    ),
                    if (_profile!['status'] == 'ACTIVE')
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
                          child: Container(
                            width: 17,
                            height: 17,
                            decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                            child: const Icon(Icons.check, size: 11, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${_profile!['firstName']} ${_profile!['lastName']}',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.navy, letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  _profile!['company'] ?? '',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
                if (_myStats != null || _badges.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          value: '${_myStats?['questionsThisMonth'] ?? '—'}',
                          label: 'Bu Ay Soru',
                        ),
                      ),
                      _StatDivider(),
                      Expanded(
                        child: _StatCard(
                          value: '${_myStats?['favoritesCount'] ?? '—'}',
                          label: 'Favori',
                        ),
                      ),
                      _StatDivider(),
                      Expanded(
                        child: _StatCard(
                          value: '${_badges.where((b) => b['earned'] == true).length}/${_badges.length}',
                          label: 'Rozet',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _openEditProfileDialog,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(color: scheme.outlineVariant),
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Profili Düzenle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                // ---- Hesap Bilgileri ----
                _ProfileSection(
                  title: 'Hesap Bilgileri',
                  children: [
                    _ProfileTile(icon: Icons.phone_outlined, title: _profile!['phone'] ?? ''),
                    _ProfileTile(icon: Icons.email_outlined, title: _profile!['email'] ?? ''),
                  ],
                ),

                // ---- Rozetler ----
                if (_badges.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ProfileSection(
                    title: 'Rozetler',
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _badges.map((b) {
                            final earned = b['earned'] == true;
                            return Opacity(
                              opacity: earned ? 1.0 : 0.35,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: scheme.outlineVariant),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(b['icon'] ?? '🏅', style: const TextStyle(fontSize: 20)),
                                    const SizedBox(height: 4),
                                    Text(
                                      b['label'] ?? '',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],

                // ---- Tercihler ----
                const SizedBox(height: AppSpacing.md),
                _ProfileSection(
                  title: 'Tercihler',
                  children: [
                    _ProfileSwitchTile(
                      icon: Icons.notifications_outlined,
                      title: 'Bildirimler',
                      value: _profile!['notificationsEnabled'] ?? true,
                      onChanged: (v) async {
                        await _dio.patch('/users/me/settings', data: {'notificationsEnabled': v});
                        setState(() => _profile!['notificationsEnabled'] = v);
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.language_outlined,
                      title: 'Dil',
                      trailing: Text(_profile!['language'] == 'tr' ? 'Türkçe' : _profile!['language']),
                    ),
                    _ProfileTile(
                      icon: Icons.settings_outlined,
                      title: 'Ayarlar',
                      subtitle: 'Bildirim türleri, sessiz saatler, yazı boyutu',
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ),

                // ---- Hesap Yönetimi ----
                const SizedBox(height: AppSpacing.md),
                _ProfileSection(
                  title: 'Hesap Yönetimi',
                  children: [
                    _ProfileTile(icon: Icons.lock_outline, title: 'Şifre Değiştir', onTap: _openChangePasswordDialog),
                    _ProfileTile(
                      icon: Icons.groups_outlined,
                      title: 'Ekip Üyelerim',
                      subtitle: 'Firma hesabınıza teknisyen ekleyin',
                      onTap: () => context.push('/team'),
                    ),
                    _ProfileTile(
                      icon: Icons.block_outlined,
                      title: 'Engellenen Bayiler',
                      onTap: () => context.push('/blocked-users'),
                    ),
                    _ProfileTile(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Bu Yıl Özetim',
                      onTap: () => context.push('/year-in-review'),
                    ),
                    _ProfileTile(
                      icon: Icons.info_outline,
                      title: 'Hakkında',
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),

                // ---- Hesap ----
                const SizedBox(height: AppSpacing.md),
                _ProfileSection(
                  title: 'Hesap',
                  children: [
                    _ProfileTile(
                      icon: Icons.logout,
                      title: 'Çıkış Yap',
                      color: AppColors.navy,
                      onTap: _logout,
                    ),
                    _ProfileTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Hesabımı Sil',
                      color: AppColors.navy,
                      onTap: _openDeleteAccountDialog,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bir profil bölümünü (başlık + gruplu satırlar) düz beyaz zeminde,
/// ince kenarlıklı bir kart içinde gösteren yardımcı widget.
class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant, letterSpacing: 0.8),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) Divider(height: 1, indent: 60, color: scheme.outlineVariant),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Nötr gri daire içinde ikon + başlık/alt başlık satırı — sade,
/// tek renkli (marka rengine bağlı olmayan) bir liste öğesi dili.
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  const _ProfileTile({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = color ?? scheme.onSurfaceVariant;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: color ?? scheme.onSurface)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)) : null,
      trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)) : null),
      onTap: onTap,
    );
  }
}

/// Avatar altındaki mini istatistik — düz zemin, sadece rakam ve etiket;
/// aradaki ince dikey çizgiyle ayrılan, tamamen nötr bir özet şeridi.
class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: Theme.of(context).colorScheme.outlineVariant);
  }
}

class _ProfileSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ProfileSwitchTile({required this.icon, required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      ),
      title: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: scheme.onSurface)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.brand,
    );
  }
}

/// Profili Düzenle penceresindeki sade, ikonlu metin alanı — odaklanınca
/// ince bir çerçeve rengi değişir, aksi halde tamamen nötr durur.
class _ProfileDialogField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _ProfileDialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  State<_ProfileDialogField> createState() => _ProfileDialogFieldState();
}

class _ProfileDialogFieldState extends State<_ProfileDialogField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _focused ? AppColors.brand : scheme.outlineVariant, width: _focused ? 1.3 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: _focused ? AppColors.brand : scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                keyboardType: widget.keyboardType,
                decoration: InputDecoration(labelText: widget.label, border: InputBorder.none, isDense: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
