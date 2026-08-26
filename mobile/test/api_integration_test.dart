import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  test('production API is reachable and protects the current-user endpoint', () async {
    expect(apiBaseUrl, isNotEmpty,
        reason: 'Run with --dart-define=API_BASE_URL=https://.../api/v1');
    final uri = Uri.tryParse(apiBaseUrl);
    expect(uri, isNotNull);
    expect(uri!.scheme, 'https', reason: 'Production API must use HTTPS');
    expect(uri.host, isNotEmpty);

    final dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (status) => status != null,
    ));

    final response = await dio.get('/users/me');

    expect(
      response.statusCode,
      anyOf(equals(401), equals(403)),
      reason: 'Unauthenticated /users/me must be rejected, not return data or a server error',
    );
  });
}

