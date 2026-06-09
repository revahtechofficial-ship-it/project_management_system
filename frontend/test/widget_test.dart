import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexax_web/app.dart';
import 'package:nexax_web/providers/auth_provider.dart';

/// Auth controller that reports unauthenticated without touching plugins.
class _UnauthController extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.unauthenticated();
}

void main() {
  testWidgets('shows the login screen when unauthenticated', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_UnauthController.new),
        ],
        child: const NexaxApp(),
      ),
    );
    // Let the async auth build + router redirect settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Sign in with Keycloak'), findsOneWidget);
  });
}
