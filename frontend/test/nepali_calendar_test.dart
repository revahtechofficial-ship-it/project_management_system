import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:revahms_web/core/utils/nepali_calendar.dart';

void main() {
  group('Devanagari digits', () {
    test('converts each digit', () {
      expect(toNepaliDigits(2083), '२०८३');
      expect(toNepaliDigits(0), '०');
      expect(toNepaliDigits(1234567890), '१२३४५६७८९०');
    });

    test('leaves non-digits alone', () {
      expect(toNepaliDigits('12-3'), '१२-३');
    });

    test('localDigits honours the language flag', () {
      expect(localDigits(25, nepali: true), '२५');
      expect(localDigits(25, nepali: false), '25');
    });
  });

  group('BS <-> AD conversion', () {
    test('Nepali New Year 2081 is 13 April 2024', () {
      expect(bsToAd(2081, 1, 1), DateTime(2024, 4, 13));
      expect(adToBs(DateTime(2024, 4, 13)), const BsDate(2081, 1, 1));
    });

    test('the day before New Year is the last day of Chaitra 2080', () {
      final BsDate bs = adToBs(DateTime(2024, 4, 12));
      expect(bs.year, 2080);
      expect(bs.month, 12);
      expect(bs.day, bsMonthLength(2080, 12));
    });

    test('round-trips every day across three BS years', () {
      DateTime day = DateTime(2024, 1, 1);
      for (int i = 0; i < 1000; i++) {
        final BsDate bs = adToBs(day);
        expect(
          bsToAd(bs.year, bs.month, bs.day),
          day,
          reason: 'round trip failed for $day (bs: $bs)',
        );
        day = DateTime(day.year, day.month, day.day + 1);
      }
    });

    // Guards the workaround: if a future nepali_utils release fixes its AD->BS
    // direction, this fails and we can drop our own adToBs.
    test('nepali_utils AD->BS is still a day ahead (why we roll our own)', () {
      final NepaliDateTime buggy = DateTime(2024, 4, 13).toNepaliDateTime();
      expect(buggy.day, 2, reason: 'package AD->BS no longer off by one');
      expect(adToBs(DateTime(2024, 4, 13)).day, 1);
    });
  });

  group('bsMonthDays', () {
    test('every day maps back to the requested BS month, in order', () {
      for (int month = 1; month <= 12; month++) {
        final List<DateTime> days = bsMonthDays(2081, month);
        expect(days.length, inInclusiveRange(29, 32),
            reason: 'implausible length for month $month');
        for (int i = 0; i < days.length; i++) {
          final BsDate bs = adToBs(days[i]);
          expect(bs, BsDate(2081, month, i + 1));
        }
      }
    });

    test('a BS year has 365 or 366 days across its twelve months', () {
      for (final int year in <int>[2080, 2081, 2082, 2083]) {
        int total = 0;
        for (int month = 1; month <= 12; month++) {
          total += bsMonthLength(year, month);
        }
        expect(total, anyOf(365, 366), reason: 'BS $year has $total days');
      }
    });

    test('consecutive months are contiguous in the Gregorian calendar', () {
      final List<DateTime> ashar = bsMonthDays(2083, 3);
      final DateTime nextMonthFirst = bsToAd(2083, 4, 1);
      expect(daysBetween(ashar.last, nextMonthFirst), 1);
    });
  });

  group('addBsMonths', () {
    test('rolls forward across the year boundary', () {
      expect(addBsMonths(2081, 12, 1), const BsDate(2082, 1, 1));
    });

    test('rolls backward across the year boundary', () {
      expect(addBsMonths(2081, 1, -1), const BsDate(2080, 12, 1));
    });

    test('moves within a year', () {
      expect(addBsMonths(2081, 3, 2), const BsDate(2081, 5, 1));
    });
  });

  group('sundayFirstIndex', () {
    test('Sunday is column 0 and Saturday column 6', () {
      expect(sundayFirstIndex(DateTime(2024, 4, 14)), 0); // a Sunday
      expect(sundayFirstIndex(DateTime(2024, 4, 20)), 6); // a Saturday
    });
  });

  group('weekend', () {
    test('both Saturday and Sunday rest', () {
      expect(isWeekend(DateTime(2026, 7, 11)), isTrue); // Saturday
      expect(isWeekend(DateTime(2026, 7, 12)), isTrue); // Sunday
    });

    test('midweek days do not', () {
      for (int day = 6; day <= 10; day++) {
        expect(
          isWeekend(DateTime(2026, 7, day)),
          isFalse,
          reason: '2026-07-$day should be a working day',
        );
      }
    });

    test('only the first and last columns rest', () {
      expect(<bool>[for (int c = 0; c < 7; c++) isWeekendColumn(c)], <bool>[
        true,
        false,
        false,
        false,
        false,
        false,
        true,
      ]);
    });
  });

  group('formatting', () {
    test('month label in both languages', () {
      expect(bsMonthLabel(2083, 3, nepali: true), 'असार २०८३');
      expect(bsMonthLabel(2083, 3, nepali: false), 'Ashar 2083');
    });

    test('dayKey pads correctly', () {
      expect(dayKey(DateTime(2026, 7, 9)), '2026-07-09');
    });

    test('eventDateLine reads Gregorian in English, BS in Nepali', () {
      // Raksha Bandhan 2026, from the seeded holiday table.
      final DateTime rakshaBandhan = DateTime(2026, 8, 28);
      expect(
        eventDateLine(rakshaBandhan, nepali: false),
        'Fri, 28 Aug 2026',
      );
      final BsDate bs = adToBs(rakshaBandhan);
      expect(
        eventDateLine(rakshaBandhan, nepali: true),
        'शुक्र, ${toNepaliDigits(bs.day)} ${kBsMonthsNe[bs.month]} '
        '${toNepaliDigits(bs.year)}',
      );
    });
  });
}
