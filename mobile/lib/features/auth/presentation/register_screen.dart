import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../data/auth_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/email_split_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _company = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _email; // EmailSplitField'dan gelen birleştirilmiş e-posta
  bool _loading = false;
  bool _obscurePassword = true;
  bool _kvkkAccepted = false;
  bool _privacyAccepted = false;
  bool _kvkkTouched = false; // "onaylanmadı" hatasını sadece denemeden sonra göster
  String? _error;

  late final TapGestureRecognizer _kvkkTapRecognizer;
  late final TapGestureRecognizer _privacyTapRecognizer;

  @override
  void initState() {
    super.initState();
    _kvkkTapRecognizer = TapGestureRecognizer()..onTap = () => context.push('/kvkk');
    _privacyTapRecognizer = TapGestureRecognizer()..onTap = () => context.push('/privacy-policy');
  }

  @override
  void dispose() {
    _kvkkTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _kvkkTouched = true);
    if (!_formKey.currentState!.validate()) return;
    if (_email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseFillEmailUsernameDomain)),
      );
      return;
    }
    if (!_kvkkAccepted || !_privacyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.kvkkConsentRequired)),
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final message = await ref.read(authRepositoryProvider).register(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            company: _company.text.trim(),
            phone: _phone.text.trim(),
            email: _email!,
            password: _password.text,
            acceptedKvkk: _kvkkAccepted,
            acceptedPrivacyPolicy: _privacyAccepted,
          );
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.registrationReceived),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/login');
              },
              child: Text(AppLocalizations.of(context)!.ok),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message'] ?? 'Kayıt başarısız. İnternet bağlantınızı kontrol edin.');
    } catch (e) {
      // Beklenmeyen herhangi bir hata da artık sessizce yutulmuyor.
      setState(() => _error = 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppPageHeader(
        backgroundColor: Colors.white,
        title: AppLocalizations.of(context)!.dealerRegistration,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- Üst kimlik bloğu ----
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          'assets/images/entpa_logo.png',
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.local_fire_department, color: AppColors.brand, size: 36),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Yeni Bayi Hesabı',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kaydınız oluşturulduktan sonra admin onayı bekler.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.brandLight,
                          borderRadius: BorderRadius.circular(AppSpacing.radius),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.brand, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.brand))),
                          ],
                        ),
                      ),

                    // ---- Bölüm: Kişisel Bilgiler ----
                    const _SectionLabel(text: 'Kişisel Bilgiler'),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(child: _field(_firstName, 'Ad', icon: Icons.person_outline)),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: _field(_lastName, 'Soyad', icon: Icons.person_outline)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _field(_company, 'Firma', icon: Icons.business_outlined),
                    const SizedBox(height: AppSpacing.xs),
                    _field(_phone, 'Telefon', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),

                    const SizedBox(height: AppSpacing.md),

                    // ---- Bölüm: Hesap Bilgileri ----
                    const _SectionLabel(text: 'Hesap Bilgileri'),
                    const SizedBox(height: AppSpacing.xs),
                    EmailSplitField(onChanged: (value) => setState(() => _email = value)),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.passwordFieldShort,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Şifre zorunludur' : null,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ---- Zorunlu hukuki metin onayları ----
                    _ConsentRow(
                      value: _kvkkAccepted,
                      onChanged: (value) => setState(() => _kvkkAccepted = value),
                      recognizer: _kvkkTapRecognizer,
                      text: 'KVKK Aydınlatma Metni\'ni okudum ve kabul ediyorum.',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _ConsentRow(
                      value: _privacyAccepted,
                      onChanged: (value) => setState(() => _privacyAccepted = value),
                      recognizer: _privacyTapRecognizer,
                      text: 'Gizlilik Politikası\'nı okudum ve kabul ediyorum.',
                    ),
                    if (_kvkkTouched && (!_kvkkAccepted || !_privacyAccepted))
                      const Padding(
                        padding: EdgeInsets.only(left: 12, top: 6),
                        child: Text(
                          'Kayıt için her iki metni de onaylamanız gerekiyor.',
                          style: TextStyle(color: AppColors.brand, fontSize: 12.5),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(AppLocalizations.of(context)!.registerAction),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(AppLocalizations.of(context)!.alreadyHaveAccount),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {required IconData icon, TextInputType? keyboardType, bool obscure = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (v) => (v == null || v.trim().isEmpty) ? '$label zorunludur' : null,
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final TapGestureRecognizer recognizer;
  final String text;

  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.recognizer,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: value ? AppColors.divider : AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: value, onChanged: (next) => onChanged(next ?? false)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                  children: [
                    TextSpan(
                      text: text,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy),
                      recognizer: recognizer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.navy, letterSpacing: 0.3),
    );
  }
}