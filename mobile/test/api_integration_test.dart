import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const compileTimeApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  final apiBaseUrl = compileTimeApiBaseUrl.isNotEmpty
      ? compileTimeApiBaseUrl
      : (Platform.environment['API_BASE_URL'] ?? '');

  test('production API is reachable and protects the current-user endpoint', () async {
    expect(apiBaseUrl, isNotEmpty,
        reason: 'Run with --dart-define=API_BASE_URL=https://.../api/v1');
    final uri = Uri.tryParse(apiBaseUrl);
    expect(uri, isNotNull);
    expect(uri!.scheme, 'https', reason: 'Production API must use HTTPS');
    expect(uri.host, isNotEmpty);

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null,
    ));
    final apiRoot = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;

    final healthResponse = await dio.getUri(Uri.parse('$apiRoot/health'));
    expect(healthResponse.statusCode, 200,
        reason: 'Production API health endpoint must be available');

    final response = await dio.getUri(Uri.parse('$apiRoot/users/me'));

    expect(
      response.statusCode,
      anyOf(equals(401), equals(403)),
      reason: 'Unauthenticated /users/me must be rejected, not return data or a server error',
    );
  });
}

