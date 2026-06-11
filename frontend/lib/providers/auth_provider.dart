import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/auth_service.dart';
import '../data/models/auth_user.dart';

/// Global authentication state (AGENTS.md §1 `providers`).
class AuthState {
  const AuthState({this.session});
  const AuthState.signedOut() : session = null;

  final AuthSession? session;

  bool get isAuthenticated => session != null;
  String? get token => session?.token;
  AuthUser? get user => session?.user;
}

/// The custom-auth API client.
final Provider<AuthService> authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Holds the session; restores a stored one on build. Only [login]/[logout]
/// change auth state — register/verify/reset deliberately do NOT sign the user
/// in (they must log in afterwards).
class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final AuthSession? session = await ref.watch(authServiceProvider).restore();
    return AuthState(session: session);
  }

  Future<void> login({required String email, required String password}) async {
    final AuthSession session =
        await ref.read(authServiceProvider).login(email: email, password: password);
    state = AsyncData<AuthState>(AuthState(session: session));
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = const AsyncData<AuthState>(AuthState.signedOut());
  }
}

final AsyncNotifierProvider<AuthController, AuthState> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
