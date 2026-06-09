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

  /// Keycloak realm issuer URL. Uses host.docker.internal so the issuer is
  /// identical for the browser and the Docker containers (Vikunja SSO).
  static const String oidcIssuer = String.fromEnvironment(
    'OIDC_ISSUER',
    defaultValue: 'http://host.docker.internal:8088/realms/revahms',
  );

  /// Public OIDC client id (PKCE).
  static const String oidcClientId = String.fromEnvironment(
    'OIDC_CLIENT_ID',
    defaultValue: 'revahms-web',
  );

  /// Redirect URI registered on the Keycloak client. The app must be served
  /// here (run with `--web-port=8090`).
  static const String oidcRedirectUri = String.fromEnvironment(
    'OIDC_REDIRECT_URI',
    defaultValue: 'http://localhost:8090/',
  );
}
