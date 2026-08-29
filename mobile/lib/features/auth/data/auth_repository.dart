import 'dart:async';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/socket_service.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/notifications/push_notification_service.dart';

class AuthRepository {
  static const _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '677096560319-i2n8hji80go4eu9u22ubi5onhi6nl5qj.apps.googleusercontent.com',
  );

  final Dio _dio = ApiClient().dio;
  final TokenStorage _tokenStorage = TokenStorage();

  // ÖNEMLİ: google_sign_in paketi 6.x'ten 7.x'e geçince API tamamen
  // değişti — artık tekil bir "instance" üzerinden, açıkça
  // initialize() edilmesi gereken bir yapı kullanılıyor. Bu, "code: 10 /
  // DEVELOPER_ERROR" hatasının olası bir nedeni olan eski platform
  // implementasyonunu (google_sign_in_android 6.2.1) devre dışı
  // bırakıp, Play App Signing ile daha uyumlu güncel implementasyona
  // (7.x) geçiyor. initialize() sadece bir kez çağrılmalı, bu yüzden
  // bir bayrak (_googleSignInReady) ile korunuyor.
  bool _googleSignInReady = false;

  Future<void> _ensureGoogleSignInReady() async {
    if (_googleSignInReady) return;
    await GoogleSignIn.instance.initialize(serverClientId: _googleServerClientId);
    _googleSignInReady = true;
  }

  Future<String> register({
    required String firstName,
    required String lastName,
    required String company,
    required String phone,
    required String email,
    required String password,
    required bool acceptedKvkk,
    required bool acceptedPrivacyPolicy,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'firstName': firstName,
      'lastName': lastName,
      'company': company,
      'phone': phone,
      'email': email,
      'password': password,
      'acceptedKvkk': acceptedKvkk,
      'acceptedPrivacyPolicy': acceptedPrivacyPolicy,
    });
    return res.data['message'] as String;
  }

  Future<void> login({required String email, required String password}) async {
    final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    await _saveSessionAndConnect(res.data['accessToken'], res.data['refreshToken']);
  }

  Future<String?> loginWithGoogle({required bool acceptedKvkk, required bool acceptedPrivacyPolicy}) async {
    await _ensureGoogleSignInReady();
    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google kimlik doğrulaması başarısız oldu.');
    }
    final res = await _dio.post('/auth/google', data: {
      'idToken': idToken,
      'acceptedKvkk': acceptedKvkk,
      'acceptedPrivacyPolicy': acceptedPrivacyPolicy,
    });
    if (res.data['accessToken'] != null) {
      await _saveSessionAndConnect(res.data['accessToken'], res.data['refreshToken']);
      return null;
    }
    return res.data['message'] as String?;
  }

  Future<String?> completePhoneLogin(
    String firebaseIdToken, {
    required bool acceptedKvkk,
    required bool acceptedPrivacyPolicy,
  }) async {
    final res = await _dio.post('/auth/phone', data: {
      'idToken': firebaseIdToken,
      'acceptedKvkk': acceptedKvkk,
      'acceptedPrivacyPolicy': acceptedPrivacyPolicy,
    });
    if (res.data['accessToken'] != null) {
      await _saveSessionAndConnect(res.data['accessToken'], res.data['refreshToken']);
      return null;
    }
    return res.data['message'] as String?;
  }

  Future<void> _saveSessionAndConnect(String accessToken, String refreshToken) async {
    await _tokenStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    await SocketService().connect();
    await CurrentUser().load();
    unawaited(PushNotificationService().initAndRegister());
  }

  Future<void> logout() async {
    await PushNotificationService().unregister();
    try {
      await _ensureGoogleSignInReady();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google oturumu bulunmasa da yerel/backend oturumu kapatılmalıdır.
    }
    SocketService().disconnect();
    CurrentUser().clear();
    await _tokenStorage.clear();
  }

  Future<bool> isLoggedIn() async => (await _tokenStorage.getAccessToken()) != null;
}
