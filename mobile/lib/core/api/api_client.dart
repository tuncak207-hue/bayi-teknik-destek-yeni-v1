import 'package:dio/dio.dart';
import 'api_config.dart';
import '../auth/token_storage.dart';

class ApiClient {
  final Dio dio;
  final TokenStorage _tokenStorage = TokenStorage();

  ApiClient._internal(this.dio);

  static ApiClient? _instance;

  factory ApiClient() {
    if (_instance != null) return _instance!;

    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    final client = ApiClient._internal(dio);

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await client._tokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await client._tryRefresh();
          if (refreshed) {
            final opts = error.requestOptions;
            final token = await client._tokenStorage.getAccessToken();
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await client.dio.fetch(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        handler.next(error);
      },
    ));

    _instance = client;
    return client;
  }

  Future<bool> _tryRefresh() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) return false;
      final res = await Dio(BaseOptions(baseUrl: ApiConfig.baseUrl)).post(
        '/auth/refresh',
        options: Options(headers: {'Authorization': 'Bearer $refreshToken'}),
      );
      await _tokenStorage.saveTokens(
        accessToken: res.data['accessToken'],
        refreshToken: res.data['refreshToken'],
      );
      return true;
    } catch (_) {
      await _tokenStorage.clear();
      return false;
    }
  }
}
