import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_providers.dart';
import 'legal_consent_dialog.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneController = TextEditingController(text: '+90');
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _loading = false;
  String? _error;
  bool get _codeSent => _verificationId != null;

  Future<void> _sendCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          // Android'de bazı cihazlar SMS kodunu otomatik algılayabilir.
          await _finishWithCredential(credential);
        },
        verificationFailed: (e) {
          setState(() {
            _error = e.message ?? 'Telefon doğrulaması başarısız oldu.';
            _loading = false;
          });
        },
        codeSent: (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
            _loading = false;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _error = 'Kod gönderilemedi. Numarayı kontrol edip tekrar deneyin.';
        _loading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _codeController.text.trim(),
    );
    await _finishWithCredential(credential);
  }

  Future<void> _finishWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) throw Exception('Kimlik doğrulama tamamlanamadı.');
      if (!mounted) return;

      final accepted = await showLegalConsentDialog(context);
      if (!accepted) {
        await FirebaseAuth.instance.signOut();
        if (mounted) setState(() => _loading = false);
        return;
      }

      final pendingMessage = await ref.read(authRepositoryProvider).completePhoneLogin(
            idToken,
            acceptedKvkk: true,
            acceptedPrivacyPolicy: true,
          );
      if (!mounted) return;

      if (pendingMessage != null) {
        // Yeni hesap oluşturuldu, admin onayı bekliyor.
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.registrationReceived),
            content: Text(pendingMessage),
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
      } else {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _error = 'Kod hatalı veya süresi doldu. Tekrar deneyin.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppPageHeader(title: AppLocalizations.of(context)!.screenPhoneLogin),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.brandLight,
                        borderRadius: BorderRadius.circular(AppSpacing.radius),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.brand)),
                    ),
                  if (!_codeSent) ...[
                    Text(
                      'Telefon numaranıza bir SMS doğrulama kodu göndereceğiz.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: AppLocalizations.of(context)!.phoneNumberField,
                        hintText: '+905551234567',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: _loading ? null : _sendCode,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(AppLocalizations.of(context)!.sendCode),
                    ),
                  ] else ...[
                    Text(
                      '${_phoneController.text.trim()} numarasına gönderilen 6 haneli kodu girin.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: AppLocalizations.of(context)!.verificationCode, prefixIcon: const Icon(Icons.sms_outlined)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: _loading ? null : _verifyCode,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(AppLocalizations.of(context)!.verifyAndLogin),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: _loading ? null : () => setState(() => _verificationId = null),
                      child: Text(AppLocalizations.of(context)!.changeNumber),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
