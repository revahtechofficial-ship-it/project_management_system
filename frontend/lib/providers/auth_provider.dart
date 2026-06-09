import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/auth_service.dart';

/// The authenticated session (AGENTS.md §1 `providers` — global state).
class AuthState {
  const AuthState({
    this.tokens,
    this.vikunjaReady = false,
    this.needsVikunjaLogin = false,
  });
  const AuthState.unauthenticated()
      : tokens = null,
        vikunjaReady = false,
        needsVikunjaLogin = false;

  final AuthTokens? tokens;

  /// Whether the BFF holds a Vikunja token for this user.
  final bool vikunjaReady;

  /// Whether the second (Vikunja) OIDC handshake still needs to run.
  final bool needsVikunjaLogin;

  bool get isAuthenticated => tokens != null;
  String? get accessToken => tokens?.accessToken;
  String get username => tokens?.username ?? '';
}

/// The OIDC service. Bare (no BFF interceptor), so no dependency cycle with
/// [dioProvider].
final Provider<AuthService> authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Holds auth state; resolves a redirect callback or stored session on build.
class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final InitResult r = await ref.watch(authServiceProvider).initialize();
    return AuthState(
      tokens: r.tokens,
      vikunjaReady: r.vikunjaReady,
      needsVikunjaLogin: r.needsVikunjaLogin,
    );
  }

  /// Redirects to Keycloak to sign in (primary BFF login).
  Future<void> login() => ref.read(authServiceProvider).beginLogin();

  /// Runs the second (silent) OIDC handshake to establish the Vikunja session.
  Future<void> connectVikunja() =>
      ref.read(authServiceProvider).beginVikunjaLogin();

  /// Clears the session and returns to unauthenticated.
  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = const AsyncData<AuthState>(AuthState.unauthenticated());
  }
}

final AsyncNotifierProvider<AuthController, AuthState> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
