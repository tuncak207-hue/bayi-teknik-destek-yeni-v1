import 'package:local_auth/local_auth.dart';

/// Parmak izi/yüz tanıma ile hızlı giriş — cihazda daha önce normal
/// (e-posta/şifre) girişi yapılmış ve oturum token'ı hâlâ geçerliyse,
/// şifreyi tekrar yazmadan sadece biyometrik onayla giriş yapılmasını sağlar.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Hesabınıza giriş yapmak için parmak izinizi doğrulayın',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
