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
  bool get isAdmin => session?.user.isAdmin ?? false;
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

  /// Updates the display name and refreshes the in-memory session.
  Future<void> updateProfile({required String fullName}) async {
    final AuthUser user = await ref
        .read(authServiceProvider)
        .updateProfile(fullName: fullName);
    final AuthSession? current = state.asData?.value.session;
    if (current != null) {
      state = AsyncData<AuthState>(AuthState(
        session: AuthSession(token: current.token, user: user),
      ));
    }
  }

  /// Changes the signed-in user's password (verifying the current one).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ref.read(authServiceProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
  }
}

final AsyncNotifierProvider<AuthController, AuthState> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
