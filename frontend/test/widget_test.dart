import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexax_web/app.dart';
import 'package:nexax_web/features/tasks/providers/tasks_providers.dart';

void main() {
  testWidgets('App renders the tasks screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Override the network-backed provider so the test stays offline.
        overrides: [
          tasksProvider.overrideWith((ref) async => []),
        ],
        child: const NexaxApp(),
      ),
    );
    await tester.pump(); // let the overridden future resolve

    expect(find.text('Nexax · Tasks'), findsOneWidget);
    expect(find.text('No tasks yet.'), findsOneWidget);
  });
}
