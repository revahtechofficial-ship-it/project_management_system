import 'package:flutter_test/flutter_test.dart';
import 'package:revahms_web/core/utils/date_search.dart';
import 'package:revahms_web/core/utils/nepali_calendar.dart';

void main() {
  group('the ambiguous year', () {
    test('a year in both ranges gives both readings, not a guess', () {
      // 2026 is a real AD year and a real BS year. Nothing in the string says
      // which was meant, so both come back — half the guesses would be wrong.
      final List<DateMatch> found = searchDates('2026-03-15');
      expect(found.length, 2);
      expect(found.map((DateMatch m) => m.readAs).toSet(), <DateCalendar>{
        DateCalendar.bs,
        DateCalendar.ad,
      });

      final DateMatch ad = found.firstWhere(
        (DateMatch m) => m.readAs == DateCalendar.ad,
      );
      expect(dayKey(ad.date), '2026-03-15');

      final DateMatch bs = found.firstWhere(
        (DateMatch m) => m.readAs == DateCalendar.bs,
      );
      expect(adToBs(bs.date), const BsDate(2026, 3, 15));
    });

    test('a year only one calendar has gives only that reading', () {
      // 2083 is far past any Gregorian year anyone means.
      final List<DateMatch> bsOnly = searchDates('2083-03-25');
      expect(bsOnly.length, 1);
      expect(bsOnly.single.readAs, DateCalendar.bs);
      expect(dayKey(bsOnly.single.date), '2026-07-09');

      // And 1995 is before the BS picker range begins.
      final List<DateMatch> adOnly = searchDates('1995-06-15');
      expect(adOnly.length, 1);
      expect(adOnly.single.readAs, DateCalendar.ad);
    });
  });

  group('numeric forms', () {
    test('reads year-first and day-first', () {
      expect(dayKey(searchDates('2083-03-25').single.date), '2026-07-09');
      expect(dayKey(searchDates('25/03/2083').single.date), '2026-07-09');
      expect(dayKey(searchDates('25.3.2083').single.date), '2026-07-09');
    });

    test('rejects a day the month does not have', () {
      // Falgun 2082 has 30 days, so there is no 32nd — and no silent rollover
      // into Chaitra.
      expect(bsMonthLength(2082, 11), lessThan(32));
      expect(searchDates('2082-11-32'), isEmpty);
    });

    test('31 February is not a date, whatever DateTime would rather do', () {
      // 1995 is outside the BS range, so only the Gregorian reading is tried —
      // and DateTime(1995, 2, 31) silently becomes 3 March, which would be a
      // quietly wrong answer rather than no answer.
      expect(DateTime(1995, 2, 31).month, DateTime.march);
      expect(searchDates('1995-02-31'), isEmpty);
    });

    test('but 31 Jestha *is* a date, so the BS reading survives', () {
      // The trap this walked into: 2026-02-31 is not a Gregorian day, yet 2026
      // is also a real BS year and Jestha has 31 days. Rejecting the whole
      // query because one calendar could not read it would lose a real date.
      final List<DateMatch> found = searchDates('2026-02-31');
      expect(found.single.readAs, DateCalendar.bs);
      expect(adToBs(found.single.date), const BsDate(2026, 2, 31));
    });
  });

  group('month names', () {
    test('finds a BS month from a partial name', () {
      expect(bsMonthFromWord('asar'), 3);
      expect(bsMonthFromWord('ash'), 3);
      expect(bsMonthFromWord('ashadh'), 3);
      expect(bsMonthFromWord('असार'), 3);
      expect(bsMonthFromWord('kartik'), 7);
      expect(bsMonthFromWord('magh'), 10);
      expect(bsMonthFromWord('nonsense'), 0);
    });

    test('finds a Gregorian month from a partial name', () {
      expect(adMonthFromWord('july'), 7);
      expect(adMonthFromWord('jul'), 7);
      expect(adMonthFromWord('dec'), 12);
      // Two letters is not enough to be sure.
      expect(adMonthFromWord('ju'), 0);
    });

    test('reads "25 asar 2083"', () {
      final List<DateMatch> found = searchDates('25 asar 2083');
      expect(found.single.readAs, DateCalendar.bs);
      expect(dayKey(found.single.date), '2026-07-09');
    });

    test('reads "9 july 2026"', () {
      final List<DateMatch> found = searchDates('9 july 2026');
      expect(found.single.readAs, DateCalendar.ad);
      expect(dayKey(found.single.date), '2026-07-09');
    });

    test('a month with no year assumes this one', () {
      final List<DateMatch> found = searchDates('asar 25');
      expect(found, isNotEmpty);
      expect(adToBs(found.first.date).month, 3);
      expect(adToBs(found.first.date).day, 25);
    });
  });

  group('Devanagari', () {
    test('reads Nepali digits', () {
      expect(asciiDigits('२०८३-०३-२५'), '2083-03-25');
      final List<DateMatch> found = searchDates('२०८३-०३-२५');
      expect(dayKey(found.single.date), '2026-07-09');
    });

    test('reads a Nepali month name', () {
      final List<DateMatch> found = searchDates('असार २५');
      expect(found, isNotEmpty);
      expect(adToBs(found.first.date).month, 3);
    });
  });

  group('what should not parse', () {
    test('a festival name is not a date', () {
      expect(searchDates('Dashain'), isEmpty);
      expect(searchDates('Holi'), isEmpty);
      expect(searchDates('दशैं'), isEmpty);
    });

    test('empty and rubbish give nothing', () {
      expect(searchDates(''), isEmpty);
      expect(searchDates('   '), isEmpty);
      expect(searchDates('99999999'), isEmpty);
      expect(searchDates('----'), isEmpty);
    });

    test('a year outside both tables gives nothing', () {
      expect(searchDates('1200-01-01'), isEmpty);
      expect(searchDates('2500-01-01'), isEmpty);
    });
  });

  group('a bare year', () {
    test('lands on the first of it, in whichever calendar it could be', () {
      final List<DateMatch> found = searchDates('2084');
      expect(found.single.readAs, DateCalendar.bs);
      expect(adToBs(found.single.date), const BsDate(2084, 1, 1));
    });
  });
}
