/// Ortama göre değiştirin (--dart-define ile build zamanında da verilebilir):
/// flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  static const socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'http://localhost:3000/chat',
  );
}
