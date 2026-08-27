/// Ortama göre değiştirin (--dart-define ile build zamanında da verilebilir):
/// flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
class ApiConfig {
  static const _isRelease = bool.fromEnvironment('dart.vm.product');
  // Android emulator host mapping: host localhost is reachable as 10.0.2.2.
  static const _debugBaseUrl = 'http://10.0.2.2:3000/api/v1';
  static const _debugSocketUrl = 'http://10.0.2.2:3000/chat';

  /// Release derlemelerinde URL’ler mutlaka build-time olarak verilmelidir.
  /// Örn: --dart-define=API_BASE_URL=https://api.example.com/api/v1
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _isRelease ? '' : _debugBaseUrl,
  );

  static const socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: _isRelease ? '' : _debugSocketUrl,
  );

  static String? get releaseValidationError {
    if (!_isRelease) return null;
    final apiError = _validateHttpsEndpoint(baseUrl, 'API_BASE_URL');
    if (apiError != null) return apiError;
    return _validateHttpsEndpoint(socketUrl, 'SOCKET_URL');
  }

  static bool get isConfigured => releaseValidationError == null;

  static String? _validateHttpsEndpoint(String value, String name) {
    if (value.trim().isEmpty) return '$name tanımlı değil.';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return '$name HTTPS ve geçerli bir host kullanmalıdır.';
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host == '0.0.0.0') {
      return '$name production’da yerel/emulator host’u kullanamaz.';
    }
    return null;
  }
}
