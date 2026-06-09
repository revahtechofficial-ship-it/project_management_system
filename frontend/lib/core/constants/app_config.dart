/// App-wide configuration constants (AGENTS.md §1 `core/constants`).
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
class AppConfig {
  const AppConfig._();

  /// Base URL of the Go backend. Defaults to the local dev server.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
