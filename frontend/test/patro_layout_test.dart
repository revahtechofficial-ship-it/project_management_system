import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:revahms_web/data/models/calendar_entry.dart';
import 'package:revahms_web/data/models/daily_content.dart';
import 'package:revahms_web/data/models/holiday.dart';
import 'package:revahms_web/data/models/muhurat.dart';
import 'package:revahms_web/features/patro/patro_page.dart';
import 'package:revahms_web/features/patro/providers/patro_providers.dart';
import 'package:revahms_web/providers/auth_provider.dart';

/// Auth that reports signed-out without touching plugins.
class _SignedOutController extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.signedOut();
}

/// The bento grid on [PatroPage] tiles many cards across the width. The one
/// thing a Row of Expanded tiles can still get wrong is overflow, and an
/// overflow is a test failure — so pumping the real page with real cards, at a
/// wide width and a narrow one, is what proves the layout is sound. The
/// analyzer cannot see a RenderFlex overflow; this can.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        // Everything the page fetches, answered instantly with nothing, so the
        // test is about the layout and not the network. Empty is the honest
        // state anyway for a fresh calendar.
        overrides: [
          authControllerProvider.overrideWith(_SignedOutController.new),
          holidaysProvider.overrideWith((Ref ref) async => const <Holiday>[]),
          holidayReminderProvider.overrideWith((Ref ref) async => null),
          calendarEntriesProvider.overrideWith(
            (Ref ref) async => const <CalendarEntry>[],
          ),
          observancesProvider.overrideWith(
            (Ref ref) async => const <Observance>[],
          ),
          muhuratsProvider.overrideWith((Ref ref) async => const <Muhurat>[]),
          quoteProvider.overrideWith((Ref ref, DateTime on) async => null),
          rashifalProvider.overrideWith(
            (Ref ref, DateTime on) async => const <Rashifal>[],
          ),
        ],
        child: const MaterialApp(home: PatroPage()),
      ),
    );
    // Not pumpAndSettle: the Nepal clock ticks forever, so the tree never
    // settles. A couple of pumps is enough for layout to run and for any
    // overflow to be thrown.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('the wide bento lays out without overflow', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(1440, 1000));

    // The page built, and the calendar — the whole point of it — is on screen.
    expect(tester.takeException(), isNull);
    expect(find.text('Calendar'), findsWidgets);
  });

  testWidgets('the narrow layout falls into one column without overflow', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(700, 1200));

    expect(tester.takeException(), isNull);
    expect(find.text('Calendar'), findsWidgets);
  });
}
