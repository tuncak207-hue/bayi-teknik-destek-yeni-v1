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

  static bool get isConfigured =>
      baseUrl.startsWith('https://') && socketUrl.startsWith('https://');
}
