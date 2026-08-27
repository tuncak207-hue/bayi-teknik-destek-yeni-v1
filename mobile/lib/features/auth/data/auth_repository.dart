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
    defaultValue: '677096560319-612fv939c3apr5sfs67pl28onlk57486.apps.googleusercontent.com',
  );

  final Dio _dio = ApiClient().dio;
  final TokenStorage _tokenStorage = TokenStorage();

  Future<String> register({
    required String firstName,
    required String lastName,
    required String company,
    required String phone,
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'company': company,
        'phone': phone,
        'email': email,
        'password': password,
      },
    );
    return res.data['message'] as String;
  }

  Future<void> login({required String email, required String password}) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    await _saveSessionAndConnect(
      res.data['accessToken'],
      res.data['refreshToken'],
    );
  }

  Future<String?> loginWithGoogle() async {
    final googleUser = await GoogleSignIn(serverClientId: _googleServerClientId)
        .signIn();
    if (googleUser == null) {
      throw Exception('Google girişi iptal edildi.');
    }
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw Exception('Google kimlik doğrulaması başarısız oldu.');
    }
    final res = await _dio.post('/auth/google', data: {'idToken': idToken});
    if (res.data['accessToken'] != null) {
      await _saveSessionAndConnect(
        res.data['accessToken'],
        res.data['refreshToken'],
      );
      return null;
    }
    return res.data['message'] as String?;
  }

  Future<String?> completePhoneLogin(String firebaseIdToken) async {
    final res = await _dio.post(
      '/auth/phone',
      data: {'idToken': firebaseIdToken},
    );
    if (res.data['accessToken'] != null) {
      await _saveSessionAndConnect(
        res.data['accessToken'],
        res.data['refreshToken'],
      );
      return null;
    }
    return res.data['message'] as String?;
  }

  Future<void> _saveSessionAndConnect(
    String accessToken,
    String refreshToken,
  ) async {
    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await SocketService().connect();
    await CurrentUser().load();
    unawaited(PushNotificationService().initAndRegister());
  }

  Future<void> logout() async {
    await PushNotificationService().unregister();
    SocketService().disconnect();
    CurrentUser().clear();
    await _tokenStorage.clear();
  }

  Future<bool> isLoggedIn() async =>
      (await _tokenStorage.getAccessToken()) != null;
}
