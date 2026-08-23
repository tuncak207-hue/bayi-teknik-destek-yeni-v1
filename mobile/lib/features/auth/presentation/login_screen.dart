import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/email_split_field.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/api/socket_service.dart';
import '../data/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  String? _email; // EmailSplitField'dan gelen birleştirilmiş e-posta
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen e-posta kullanıcı adı ve uzantı alanlarının ikisini de doldurun.')),
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).login(
            email: _email!,
            password: _passwordController.text,
          );
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message'] ?? 'Giriş başarısız.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _googleLoading = false;
  bool _biometricLoading = false;
  bool _biometricAvailable = false;
  final _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  /// Parmak izi butonu, sadece cihazda biyometrik donanım VE daha önce
  /// (e-posta/şifre ile) kaydedilmiş geçerli bir oturum token'ı varsa
  /// gösterilir — aksi halde tıklanınca "önce normal giriş yapın" demek
  /// zorunda kalırdık, bu kafa karıştırıcı olurdu.
  Future<void> _checkBiometricAvailability() async {
    final hasToken = await TokenStorage().getAccessToken() != null;
    final deviceSupports = await _biometricService.isAvailable();
    if (mounted) setState(() => _biometricAvailable = hasToken && deviceSupports);
  }

  Future<void> _submitBiometric() async {
    setState(() => _biometricLoading = true);
    try {
      final confirmed = await _biometricService.authenticate();
      if (!confirmed) return;
      // Zaten kayıtlı, geçerli token ile sessizce oturumu devam ettiriyoruz —
      // şifreye hiç ihtiyaç yok.
      await CurrentUser().load();
      await SocketService().connect();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Parmak izi doğrulaması başarısız oldu, lütfen e-posta/şifre ile giriş yapın.');
      }
    } finally {
      if (mounted) setState(() => _biometricLoading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      final pendingMessage = await ref.read(authRepositoryProvider).loginWithGoogle();
      if (!mounted) return;
      if (pendingMessage != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Kayıt Alındı'),
            content: Text(pendingMessage),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
          ),
        );
      } else {
        context.go('/home');
      }
    } catch (e) {
      // Gerçek hata mesajını da terminale (debug console) yazdırıyoruz —
      // "Google ile giriş yapılamadı" tek başına teşhis için yetersiz kalıyordu.
      // ignore: avoid_print
      print('[google_login] Hata: $e');
      setState(() => _error = 'Google ile giriş yapılamadı: $e');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Image.asset(
                          'assets/images/entpa_logo.png',
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.local_fire_department, color: AppColors.primary, size: 44),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'ENTPA Mühendislik Hizmeti',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 0.2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bayi Teknik Destek Platformu',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(_error!, style: const TextStyle(color: AppColors.errorColor), textAlign: TextAlign.center),
                      ),
                    EmailSplitField(onChanged: (value) => setState(() => _email = value)),
                    const SizedBox(height: AppSpacing.sm),
                    // ÖNEMLİ: TextFormField olarak kalıyor (AppTextField'a
                    // geçmiyor) çünkü Form'un validate() kontrolü buna
                    // bağlı — sadece görsel dili yeni sisteme (AppColors/
                    // AppRadius) hizalandı.
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: AppColors.surfaceBase,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.outline)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.outline)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary, width: 1.4)),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Şifre en az 6 karakter olmalı' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(label: 'Giriş Yap', onPressed: _submit, loading: _loading),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Hesabınız yok mu? Kayıt olun'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.outline)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('veya', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ),
                        Expanded(child: Divider(color: AppColors.outline)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.secondary(
                      label: 'Google ile Giriş Yap',
                      onPressed: _submitGoogle,
                      loading: _googleLoading,
                      icon: Icons.g_mobiledata,
                    ),
                    if (_biometricAvailable) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppButton.secondary(
                        label: 'Parmak İzi ile Giriş Yap',
                        onPressed: _submitBiometric,
                        loading: _biometricLoading,
                        icon: Icons.fingerprint,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
