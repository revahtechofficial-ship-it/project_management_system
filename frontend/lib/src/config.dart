/// App-wide configuration. Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
class AppConfig {
  /// Base URL of the Go backend. Defaults to the local dev server.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
