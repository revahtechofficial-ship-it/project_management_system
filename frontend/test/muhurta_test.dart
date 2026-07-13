import 'package:flutter_test/flutter_test.dart';
import 'package:revahms_web/core/utils/muhurta.dart';
import 'package:revahms_web/core/utils/nepali_calendar.dart';

void main() {
  group('Rahu Kaal follows the published table', () {
    // The part of the day (1-8) Rahu takes, by weekday. Every panchang prints
    // this: Sunday afternoon last, Monday morning early, and so on.
    const Map<int, int> expected = <int, int>{
      0: 8, // Sunday
      1: 2, // Monday
      2: 7, // Tuesday
      3: 5, // Wednesday
      4: 6, // Thursday
      5: 4, // Friday
      6: 3, // Saturday
    };

    test('lands in the right eighth of the day, every weekday', () {
      // A week of July 2026: the 5th is a Sunday.
      for (int i = 0; i < 7; i++) {
        final DateTime day = DateTime(2026, 7, 5 + i);
        final DayMuhurtas m = muhurtasFor(day);
        final int weekday = sundayFirstIndex(day);
        final int eighthMs = m.sunset.difference(m.sunrise).inMilliseconds ~/ 8;
        final DateTime want = m.sunrise.add(
          Duration(milliseconds: eighthMs * (expected[weekday]! - 1)),
        );
        expect(
          m.rahuKaal.start.difference(want).inSeconds.abs(),
          lessThan(2),
          reason:
              '${day.toIso8601String()} (weekday $weekday): Rahu should open '
              'the ${expected[weekday]}th eighth at $want, '
              'got ${m.rahuKaal.start}',
        );
      }
    });

    test('the whole week matches the table, as clock times', () {
      // Every published table quotes an idealised 6am-6pm day, on which an
      // eighth is exactly 90 minutes. Kathmandu's real day is not that, so
      // the windows shift — but the *ordering* through the week is the
      // signature of the table, and it must hold.
      final List<int> rahuEighths = <int>[];
      for (int i = 0; i < 7; i++) {
        final DateTime day = DateTime(2026, 7, 5 + i);
        final DayMuhurtas m = muhurtasFor(day);
        final double eighths =
            m.rahuKaal.start.difference(m.sunrise).inMilliseconds /
            (m.sunset.difference(m.sunrise).inMilliseconds / 8);
        rahuEighths.add(eighths.round() + 1);
      }
      // Sunday through Saturday.
      expect(rahuEighths, <int>[8, 2, 7, 5, 6, 4, 3]);
    });

    test('never falls on the same eighth two days running', () {
      final Set<int> parts = expected.values.toSet();
      expect(parts.length, 7, reason: 'each weekday takes a different part');
    });
  });

  group('Gulika and Yamaganda follow their tables too', () {
    /// Which eighth [window] opens, on [day].
    int eighthOf(Muhurta window, DayMuhurtas m) {
      final double e =
          window.start.difference(m.sunrise).inMilliseconds /
          (m.sunset.difference(m.sunrise).inMilliseconds / 8);
      return e.round() + 1;
    }

    test('Gulika walks backwards from Saturday', () {
      final List<int> got = <int>[];
      for (int i = 0; i < 7; i++) {
        final DayMuhurtas m = muhurtasFor(DateTime(2026, 7, 5 + i));
        got.add(eighthOf(m.gulikaKaal, m));
      }
      expect(got, <int>[7, 6, 5, 4, 3, 2, 1]);
    });

    test('Yamaganda runs down to Thursday, then jumps', () {
      final List<int> got = <int>[];
      for (int i = 0; i < 7; i++) {
        final DayMuhurtas m = muhurtasFor(DateTime(2026, 7, 5 + i));
        got.add(eighthOf(m.yamaganda, m));
      }
      expect(got, <int>[5, 4, 3, 2, 1, 7, 6]);
    });
  });

  group('the three inauspicious windows', () {
    test('are each an eighth of the daylight, and never overlap', () {
      for (int day = 1; day <= 28; day++) {
        final DayMuhurtas m = muhurtasFor(DateTime(2026, 4, day));
        final Duration daylight = m.sunset.difference(m.sunrise);
        final int eighth = daylight.inMinutes ~/ 8;

        for (final Muhurta w in <Muhurta>[
          m.rahuKaal,
          m.gulikaKaal,
          m.yamaganda,
        ]) {
          expect(w.length.inMinutes, closeTo(eighth, 1), reason: w.nameEn);
          expect(w.auspicious, isFalse);
          expect(
            !w.start.isBefore(m.sunrise) && !w.end.isAfter(m.sunset),
            isTrue,
            reason: '${w.nameEn} must lie inside the day',
          );
        }

        // Rahu, Gulika and Yamaganda take three different eighths.
        final List<DateTime> starts = <DateTime>[
          m.rahuKaal.start,
          m.gulikaKaal.start,
          m.yamaganda.start,
        ];
        expect(starts.toSet().length, 3, reason: 'April $day: they collided');
      }
    });

    test('are shorter in December than in June, because the day is', () {
      final DayMuhurtas june = muhurtasFor(DateTime(2026, 6, 21));
      final DayMuhurtas december = muhurtasFor(DateTime(2026, 12, 21));
      expect(
        june.rahuKaal.length > december.rahuKaal.length,
        isTrue,
        reason:
            'June ${june.rahuKaal.length}, '
            'December ${december.rahuKaal.length}',
      );
      // About 102 minutes in midsummer, about 79 at the solstice.
      expect(june.rahuKaal.length.inMinutes, inInclusiveRange(95, 110));
      expect(december.rahuKaal.length.inMinutes, inInclusiveRange(75, 85));
    });
  });

  group('Abhijit', () {
    test('straddles the middle of the day', () {
      final DayMuhurtas m = muhurtasFor(DateTime(2026, 7, 9));
      final DateTime midday = m.sunrise.add(
        Duration(
          milliseconds: m.sunset.difference(m.sunrise).inMilliseconds ~/ 2,
        ),
      );
      expect(m.abhijit.contains(midday), isTrue);
      expect(m.abhijit.auspicious, isTrue);
    });

    test('is a fifteenth of the day, not an eighth', () {
      final DayMuhurtas m = muhurtasFor(DateTime(2026, 7, 9));
      final int fifteenth = m.sunset.difference(m.sunrise).inMinutes ~/ 15;
      expect(m.abhijit.length.inMinutes, closeTo(fifteenth, 1));
    });

    test('is held not to apply on a Wednesday', () {
      // 8 July 2026 is a Wednesday.
      expect(DateTime(2026, 7, 8).weekday, DateTime.wednesday);
      expect(muhurtasFor(DateTime(2026, 7, 8)).hasAbhijit, isFalse);
      expect(muhurtasFor(DateTime(2026, 7, 9)).hasAbhijit, isTrue);
      // It is still computed, just not offered.
      expect(
        muhurtasFor(
          DateTime(2026, 7, 8),
        ).all.contains(muhurtasFor(DateTime(2026, 7, 8)).abhijit),
        isFalse,
      );
    });
  });

  group('looking a moment up', () {
    test('finds the window a time falls in', () {
      final DayMuhurtas m = muhurtasFor(DateTime(2026, 7, 9));
      final DateTime insideRahu = m.rahuKaal.start.add(
        const Duration(minutes: 5),
      );
      expect(m.at(insideRahu)?.nameEn, 'Rahu Kaal');
      // Sunrise itself is not in Rahu Kaal on a Thursday (Rahu takes the 6th).
      expect(m.at(m.sunrise)?.nameEn, isNot('Rahu Kaal'));
    });

    test('an inauspicious window wins a clash with Abhijit', () {
      // On a Wednesday Rahu takes the fifth eighth, which straddles midday and
      // so overlaps Abhijit. A patro reads that as inauspicious.
      final DayMuhurtas wed = muhurtasFor(DateTime(2026, 7, 8));
      final DateTime midAbhijit = wed.abhijit.start.add(
        Duration(milliseconds: wed.abhijit.length.inMilliseconds ~/ 2),
      );
      expect(wed.at(midAbhijit)?.auspicious, isFalse);
    });
  });
}
