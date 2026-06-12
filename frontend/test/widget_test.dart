import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:revahms_web/app.dart';
import 'package:revahms_web/providers/auth_provider.dart';

/// Auth controller that reports signed-out without touching plugins.
class _SignedOutController extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.signedOut();
}

void main() {
  testWidgets('shows the landing page when signed out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutController.new),
        ],
        child: const RevahApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Signed-out visitors land on the public marketing page first.
    expect(find.text('Run every project'), findsOneWidget);
    expect(find.text('Get started'), findsWidgets);
  });
}
