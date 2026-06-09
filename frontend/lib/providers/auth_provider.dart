import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/auth_service.dart';

/// The authenticated session (AGENTS.md §1 `providers` — global state).
class AuthState {
  const AuthState({this.tokens});
  const AuthState.unauthenticated() : tokens = null;

  final AuthTokens? tokens;

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
    final AuthTokens? tokens =
        await ref.watch(authServiceProvider).initialize();
    return AuthState(tokens: tokens);
  }

  /// Redirects to Keycloak to sign in.
  Future<void> login() => ref.read(authServiceProvider).beginLogin();

  /// Clears the session and returns to unauthenticated.
  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = const AsyncData<AuthState>(AuthState.unauthenticated());
  }
}

final AsyncNotifierProvider<AuthController, AuthState> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
