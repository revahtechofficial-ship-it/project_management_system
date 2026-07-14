import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revahms_web/features/patro/providers/patro_providers.dart';
import 'package:revahms_web/features/patro/widgets/day_card.dart';
import 'package:revahms_web/features/patro/widgets/day_cell.dart';

void main() {
  // 25 June 2026 — the day from the specification. 11 Ashar 2083, a Thursday,
  // Nirjala Ekadashi.
  final DateTime day = DateTime(2026, 6, 25);

  int taps = 0;
  int details = 0;
  int notes = 0;
  int reminders = 0;

  Widget harness({bool selected = false}) {
    return MaterialApp(
      home: Scaffold(
        // Somewhere for the card to be pushed away from, so the cell is not
        // hard against a screen edge.
        body: Center(
          child: SizedBox(
            width: 90,
            height: 70,
            child: DayCell(
              date: day,
              bsDay: 11,
              outside: false,
              reserveNameLine: true,
              nepali: false,
              isToday: false,
              isSelected: selected,
              events: const <CalendarEvent>[],
              onTap: () => taps++,
              onShowDetails: () => details++,
              onAddNote: () => notes++,
              onSetReminder: () => reminders++,
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    taps = 0;
    details = 0;
    notes = 0;
    reminders = 0;
  });

  group('hovering a day', () {
    testWidgets('does not raise the card', (WidgetTester tester) async {
      // The whole point of the change. Reading a month means dragging the
      // pointer across thirty-five cells; if each one threw a card up, the
      // calendar would be unreadable.
      await tester.pumpWidget(harness());
      expect(find.byType(DayCard), findsNothing);

      final TestGesture pointer = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);

      await pointer.moveTo(tester.getCenter(find.byType(DayCell)));
      await tester.pumpAndSettle();

      expect(find.byType(DayCard), findsNothing);
      expect(taps, 0, reason: 'hovering must not select the day either');
    });

    testWidgets('lights the cell up', (WidgetTester tester) async {
      await tester.pumpWidget(harness());

      BoxDecoration decorationNow() {
        final AnimatedContainer container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        return container.decoration! as BoxDecoration;
      }

      final Border resting = decorationNow().border! as Border;

      final TestGesture pointer = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      await pointer.moveTo(tester.getCenter(find.byType(DayCell)));
      await tester.pumpAndSettle();

      final Border hovered = decorationNow().border! as Border;

      // It says "the click would land here" and nothing more: a firmer outline
      // in the theme's own primary colour.
      expect(hovered.top.color, isNot(resting.top.color));
      expect(hovered.top.width, greaterThan(resting.top.width));

      // And it lets go when the pointer does.
      await pointer.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(
        (decorationNow().border! as Border).top.color,
        resting.top.color,
      );
    });
  });

  group('clicking a day', () {
    testWidgets('selects it and raises the card', (WidgetTester tester) async {
      await tester.pumpWidget(harness());

      await tester.tap(find.byType(DayCell));
      await tester.pumpAndSettle();

      // Both: the click means "this day" and "tell me about it".
      expect(taps, 1);
      expect(find.byType(DayCard), findsOneWidget);

      // And the card is the one for this day, worked out on the spot.
      expect(find.text('Ashar 11, 2083'), findsOneWidget);
      expect(find.textContaining('Nirjala Ekadashi'), findsOneWidget);
    });

    testWidgets('closes on a click anywhere else', (WidgetTester tester) async {
      await tester.pumpWidget(harness());
      await tester.tap(find.byType(DayCell));
      await tester.pumpAndSettle();
      expect(find.byType(DayCard), findsOneWidget);

      // The far corner, well clear of both the cell and the card.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(DayCard), findsNothing);
    });

    testWidgets('closes on Escape', (WidgetTester tester) async {
      await tester.pumpWidget(harness());
      await tester.tap(find.byType(DayCell));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(DayCard), findsNothing);
    });
  });

  group('the quick buttons', () {
    testWidgets('each fire once, and close the card', (
      WidgetTester tester,
    ) async {
      // The reason the card is click-driven rather than hover-driven: a card
      // that vanished when the pointer left the cell could not be clicked at
      // all. These buttons only work because the card stays put.
      for (final (String label, int Function() count) button
          in <(String, int Function())>[
            ('Details', () => details),
            ('Note', () => notes),
            ('Remind', () => reminders),
          ]) {
        await tester.pumpWidget(harness());
        await tester.tap(find.byType(DayCell));
        await tester.pumpAndSettle();

        await tester.tap(find.text(button.$1));
        await tester.pumpAndSettle();

        expect(button.$2(), 1, reason: '${button.$1} should have fired once');
        expect(
          find.byType(DayCard),
          findsNothing,
          reason: '${button.$1} should not leave the card over its own result',
        );
      }
    });
  });
}
