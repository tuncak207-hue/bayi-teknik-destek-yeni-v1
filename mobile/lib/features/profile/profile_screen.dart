import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../auth/data/auth_repository.dart';
import '../dealers/blocked_users_screen.dart';
import '../../core/events/notification_badge_bus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Dio _dio = ApiClient().dio;
  Map<String, dynamic>? _profile;
  int _unreadNotifications = 0;
  String? _loadError;
  List<dynamic> _badges = [];
  Map<String, dynamic>? _myStats;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUnreadCount();
    _loadBadges();
    _loadMyStats();
    // Bildirim geldiğinde bu ekrandaki zil sayısı da anlık güncellensin.
    NotificationBadgeBus.trigger.addListener(_loadUnreadCount);
  }

  @override
  void dispose() {
    NotificationBadgeBus.trigger.removeListener(_loadUnreadCount);
    super.dispose();
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

  Future<void> _loadUnreadCount() async {
    try {
      final res = await _dio.get('/notifications/unread-count');
      if (mounted) setState(() => _unreadNotifications = res.data['count'] ?? 0);
    } catch (_) {
      // Sessizce yut, rozet ikincil bir bilgi.
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
                      child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  _PremiumDialogField(controller: firstNameController, label: 'Ad', icon: Icons.person_outline),
                  const SizedBox(height: 10),
                  _PremiumDialogField(controller: lastNameController, label: 'Soyad', icon: Icons.person_outline),
                  const SizedBox(height: 10),
                  _PremiumDialogField(
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
                      child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
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
    final passwordController = TextEditingController();
    String? error;

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
                    'Bu işlem geri alınamaz. Hesabınız kalıcı olarak devre dışı bırakılacak ve '
                    'bir daha giriş yapamayacaksınız. Devam etmek için şifrenizi girin.',
                    style: TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 16),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Şifreniz'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  try {
                    await _dio.delete('/users/me', data: {'password': passwordController.text});
                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                  } on DioException catch (e) {
                    setDialogState(() => error = e.response?.data?['message'] ?? 'Hesap silinemedi.');
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
        appBar: AppBar(title: const Text('Profil')),
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

    // ÖNEMLİ DÜZELTME: "mesajlara/profile basınca geri ok işareti çıksın,
    // menü değil" — tam paylaşılan menü yerine, AI ekranındaki gibi
    // sadece basit bir geri oku olan AppBar'a dönüldü.
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: const Text('Profil'),
        leading: Navigator.of(context).canPop()
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop())
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
      ),
      body: ListView(
            children: [
          // ---- Üst kimlik bandı: beyaz zemin ama çok katmanlı, göz alıcı bir
          // görsel doku ile — arka planda ince gradyan "halo" lekeleri,
          // büyük tipografi, çok katmanlı gölgeli avatar.
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Colors.white),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Arka planda, çok hafif iki renkli "halo" lekesi — beyaz
                // zeminde bile derinlik hissi veriyor, düz/sıradan durmasın diye.
                Positioned(
                  top: -60,
                  right: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [AppColors.brand.withOpacity(0.10), Colors.transparent]),
                    ),
                  ),
                ),
                Positioned(
                  top: -20,
                  left: -60,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [AppColors.navy.withOpacity(0.06), Colors.transparent]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, AppSpacing.lg),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const SweepGradient(
                                colors: [AppColors.brand, AppColors.navy, AppColors.brand],
                              ),
                              boxShadow: [
                                BoxShadow(color: AppColors.brand.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 8)),
                                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: const Color(0xFFF0F2F5),
                                backgroundImage: _profile!['avatarUrl'] != null ? NetworkImage(_profile!['avatarUrl']) : null,
                                child: _profile!['avatarUrl'] == null
                                    ? Text(
                                        _initials(_profile!['firstName'], _profile!['lastName']),
                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          if (_profile!['status'] == 'ACTIVE')
                            Positioned(
                              right: 0,
                              bottom: 2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.4), blurRadius: 8)],
                                  ),
                                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppColors.navy, Color(0xFF1D3A56)],
                        ).createShader(bounds),
                        child: Text(
                          '${_profile!['firstName']} ${_profile!['lastName']}',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.navy.withOpacity(0.06), AppColors.brand.withOpacity(0.06)]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.navy.withOpacity(0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.workspace_premium, size: 13, color: AppColors.brand),
                            const SizedBox(width: 6),
                            Text(
                              _profile!['company'] ?? '',
                              style: const TextStyle(color: AppColors.navy, fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      if (_myStats != null || _badges.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.smart_toy_outlined,
                                value: '${_myStats?['questionsThisMonth'] ?? '—'}',
                                label: 'Bu Ay Soru',
                                accent: AppColors.navy,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.bookmark_border,
                                value: '${_myStats?['favoritesCount'] ?? '—'}',
                                label: 'Favori',
                                accent: AppColors.brand,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.emoji_events_outlined,
                                value: '${_badges.where((b) => b['earned'] == true).length}/${_badges.length}',
                                label: 'Rozet',
                                accent: const Color(0xFFCA8A04),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _openEditProfileDialog,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: const BorderSide(color: AppColors.divider),
                          foregroundColor: AppColors.navy,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Profili Düzenle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 8, color: const Color(0xFFFFFFFF)),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
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
                        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
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
                                  color: earned ? AppColors.navy.withOpacity(0.06) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(b['icon'] ?? '🏅', style: const TextStyle(fontSize: 22)),
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
                    _ProfileSwitchTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Karanlık Tema',
                      value: _profile!['darkMode'] ?? false,
                      onChanged: (v) async {
                        ThemeController().setDark(v);
                        await _dio.patch('/users/me/settings', data: {'darkMode': v});
                        setState(() => _profile!['darkMode'] = v);
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

                // ---- Tehlikeli Bölge ----
                const SizedBox(height: AppSpacing.md),
                _ProfileSection(
                  title: 'Hesap',
                  children: [
                    _ProfileTile(
                      icon: Icons.logout,
                      title: 'Çıkış Yap',
                      color: Colors.red,
                      onTap: _logout,
                    ),
                    _ProfileTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Hesabımı Sil',
                      color: Colors.red,
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

/// Bir profil bölümünü (başlık + gruplu satırlar) beyaz, hafif gölgeli bir
/// kart içinde gösteren yardımcı widget — önceden tüm satırlar tek bir
/// kartta karışık şekilde duruyordu, artık her biri kendi başlığı altında.
class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.8),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) Divider(height: 1, indent: 64, color: Colors.grey.shade100),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Renkli daire içinde ikon + başlık/alt başlık satırı — önceki düz gri
/// ikonlar yerine, daha "premium" bir görünüm için lacivert tonlu rozet.
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
    final tileColor = color ?? AppColors.navy;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: tileColor.withOpacity(0.08), borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 18, color: tileColor),
      ),
      title: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: color ?? const Color(0xFF1C1C1E))),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)) : null,
      trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade300) : null),
      onTap: onTap,
    );
  }
}

/// Avatar altındaki mini istatistik kartları — büyük SaaS/fintech
/// uygulamalarındaki (Revolut, Linear vb.) profil özetlerine benzer.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  const _StatCard({required this.icon, required this.value, required this.label, this.accent = AppColors.brand});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.07), accent.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: accent.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 13, color: accent),
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.navy)),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
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
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.08), borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 18, color: AppColors.navy),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: Color(0xFF1C1C1E))),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.brand,
    );
  }
}

/// Kullanıcı isteği: "profil kısmı çok kötü" — özellikle "Profili
/// Düzenle" penceresindeki sade TextField'lar, premium bir alana
/// çevrildi (ikonlu, hafif gölgeli, odaklanınca canlanan çerçeve).
class _PremiumDialogField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _PremiumDialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  State<_PremiumDialogField> createState() => _PremiumDialogFieldState();
}

class _PremiumDialogFieldState extends State<_PremiumDialogField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _focused ? AppColors.brand : Colors.grey.shade200, width: _focused ? 1.3 : 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: _focused ? AppColors.brand : Colors.grey.shade400),
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
