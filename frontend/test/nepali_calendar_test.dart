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
        expect(
          days.length,
          inInclusiveRange(29, 32),
          reason: 'implausible length for month $month',
        );
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

  group('bsMonthGrid', () {
    test('always fills whole weeks, starting on a Sunday', () {
      for (int month = 1; month <= 12; month++) {
        final List<DateTime> grid = bsMonthGrid(2083, month);
        expect(grid.length % 7, 0, reason: 'month $month is not whole weeks');
        expect(sundayFirstIndex(grid.first), 0, reason: 'month $month');
        expect(sundayFirstIndex(grid.last), 6, reason: 'month $month');
      }
    });

    test('is contiguous and contains the whole month', () {
      final List<DateTime> grid = bsMonthGrid(2083, 3);
      for (int i = 1; i < grid.length; i++) {
        expect(daysBetween(grid[i - 1], grid[i]), 1);
      }
      for (final DateTime day in bsMonthDays(2083, 3)) {
        expect(grid, contains(day));
      }
    });

    test('pads with the neighbouring months, never the same month', () {
      final List<DateTime> month = bsMonthDays(2083, 1);
      final List<DateTime> grid = bsMonthGrid(2083, 1);
      final List<DateTime> padding = <DateTime>[
        for (final DateTime day in grid)
          if (!month.contains(day)) day,
      ];
      for (final DateTime day in padding) {
        expect(adToBs(day).month, isNot(1));
      }
      expect(grid.length - padding.length, month.length);
    });

    test('a month starting on a Sunday needs no leading padding', () {
      BsDate? sundayStart;
      for (int year = 2080; year <= 2085 && sundayStart == null; year++) {
        for (int month = 1; month <= 12; month++) {
          if (sundayFirstIndex(bsToAd(year, month, 1)) == 0) {
            sundayStart = BsDate(year, month, 1);
            break;
          }
        }
      }
      expect(sundayStart, isNotNull, reason: 'no BS month starts on a Sunday?');

      final BsDate bs = sundayStart!;
      final List<DateTime> grid = bsMonthGrid(bs.year, bs.month);
      expect(grid.first, bsToAd(bs.year, bs.month, 1));
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
      expect(
        <bool>[for (int c = 0; c < 7; c++) isWeekendColumn(c)],
        <bool>[true, false, false, false, false, false, true],
      );
    });
  });

  group('isoWeekNumber', () {
    test('1 Jan 2026 is a Thursday, so it opens week 1', () {
      expect(DateTime(2026, 1, 1).weekday, DateTime.thursday);
      expect(isoWeekNumber(DateTime(2026, 1, 1)), 1);
    });

    test('a week belongs to the year holding its Thursday', () {
      // 2026 starts on a Thursday and so runs to 53 weeks; 1 Jan 2027 (a
      // Friday) still belongs to that 53rd week, not to week 1 of 2027.
      expect(isoWeekNumber(DateTime(2026, 12, 31)), 53);
      expect(isoWeekNumber(DateTime(2027, 1, 1)), 53);
      expect(isoWeekNumber(DateTime(2027, 1, 4)), 1); // the Monday after
    });

    test('a late-December Monday can already be week 1 of the next year', () {
      expect(DateTime(2024, 12, 30).weekday, DateTime.monday);
      expect(isoWeekNumber(DateTime(2024, 12, 30)), 1);
    });

    test('weeks advance by one every seven days', () {
      for (int i = 0; i < 7; i++) {
        expect(isoWeekNumber(DateTime(2026, 3, 2 + i)), 10);
      }
      expect(isoWeekNumber(DateTime(2026, 3, 9)), 11);
    });
  });

  group('bsWeekOfYear', () {
    test('Baishakh 1 always falls in week 1', () {
      for (final int year in <int>[2081, 2082, 2083, 2084]) {
        expect(bsWeekOfYear(bsToAd(year, 1, 1)), 1, reason: 'BS $year');
      }
    });

    test('increments on Sunday, never mid-week', () {
      final DateTime start = bsToAd(2083, 1, 1);
      int previous = bsWeekOfYear(start);
      for (int i = 1; i < 60; i++) {
        final DateTime day = DateTime(start.year, start.month, start.day + i);
        final int week = bsWeekOfYear(day);
        if (sundayFirstIndex(day) == 0) {
          expect(week, previous + 1, reason: 'should tick over on $day');
        } else {
          expect(week, previous, reason: 'should hold steady on $day');
        }
        previous = week;
      }
    });

    // A BS year ends in week 53 at the earliest — 365 days from a Sunday is
    // 52 full weeks plus one day. It reaches 54 when the year is 366 days and
    // opens on a Saturday, so week 1 holds a single day: BS 2081 does exactly
    // that. Neither is an off-by-one.
    test('the last day of a BS year lands in week 53 or 54', () {
      for (final int year in <int>[2081, 2082, 2083]) {
        final DateTime lastDay = bsToAd(year, 12, bsMonthLength(year, 12));
        expect(
          bsWeekOfYear(lastDay),
          inInclusiveRange(53, 54),
          reason: 'BS $year ends in week ${bsWeekOfYear(lastDay)}',
        );
      }
    });

    test('BS 2081 needs 54 weeks: 366 days opening on a Saturday', () {
      expect(sundayFirstIndex(bsToAd(2081, 1, 1)), 6);
      int total = 0;
      for (int month = 1; month <= 12; month++) {
        total += bsMonthLength(2081, month);
      }
      expect(total, 366);
      expect(bsWeekOfYear(bsToAd(2081, 12, bsMonthLength(2081, 12))), 54);
    });
  });

  group('Nepal time', () {
    test('is UTC+05:45', () {
      expect(kNepalOffset, const Duration(hours: 5, minutes: 45));
      expect(
        nepalTimeOf(DateTime.utc(2026, 7, 9, 6)),
        DateTime.utc(2026, 7, 9, 11, 45),
      );
    });

    test('does not depend on the device zone', () {
      // Same instant, expressed two ways: the Nepal reading must match.
      final DateTime utc = DateTime.utc(2026, 7, 9, 18, 30);
      expect(nepalTimeOf(utc), nepalTimeOf(utc.toLocal()));
    });

    test('rolls the date over when Nepal is already tomorrow', () {
      final DateTime nepal = nepalTimeOf(DateTime.utc(2026, 7, 9, 20));
      expect(nepal.day, 10);
      expect(nepal.hour, 1);
      expect(nepal.minute, 45);
    });

    test('meridiem names the stretch of day, not just AM/PM', () {
      expect(nepaliMeridiem(2), 'राति');
      expect(nepaliMeridiem(9), 'बिहान');
      expect(nepaliMeridiem(13), 'दिउँसो');
      expect(nepaliMeridiem(18), 'साँझ');
      expect(nepaliMeridiem(22), 'राति');
    });

    test('formatClock reads a 12-hour clock', () {
      final DateTime afternoon = DateTime.utc(2026, 7, 9, 13, 5, 9);
      expect(formatClock(afternoon, nepali: false), '1:05:09 PM');
      expect(formatClock(afternoon, nepali: true), '१:०५:०९ दिउँसो');
    });

    test('formatClock shows midnight and noon as 12, not 0', () {
      expect(
        formatClock(DateTime.utc(2026, 7, 9, 0, 0, 0), nepali: false),
        '12:00:00 AM',
      );
      expect(
        formatClock(DateTime.utc(2026, 7, 9, 12, 0, 0), nepali: false),
        '12:00:00 PM',
      );
    });
  });

  group('supported year range', () {
    test('the picker stays inside what the conversion table covers', () {
      expect(kBsPickerMinYear, greaterThanOrEqualTo(kBsMinYear));
      expect(kBsPickerMaxYear, lessThanOrEqualTo(kBsMaxYear));
    });

    test('both ends of the picker range actually convert', () {
      for (final int year in <int>[kBsPickerMinYear, kBsPickerMaxYear]) {
        expect(() => bsMonthGrid(year, 1), returnsNormally);
        expect(() => bsMonthGrid(year, 12), returnsNormally);
        expect(adToBs(bsToAd(year, 12, 1)), BsDate(year, 12, 1));
      }
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
      expect(eventDateLine(rakshaBandhan, nepali: false), 'Fri, 28 Aug 2026');
      final BsDate bs = adToBs(rakshaBandhan);
      expect(
        eventDateLine(rakshaBandhan, nepali: true),
        'शुक्र, ${toNepaliDigits(bs.day)} ${kBsMonthsNe[bs.month]} '
        '${toNepaliDigits(bs.year)}',
      );
    });
  });
}
