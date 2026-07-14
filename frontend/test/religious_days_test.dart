import 'package:flutter_test/flutter_test.dart';
import 'package:revahms_web/core/utils/nepali_calendar.dart';
import 'package:revahms_web/core/utils/panchang.dart';
import 'package:revahms_web/core/utils/religious_days.dart';

void main() {
  group('against Hamro Patro', () {
    // The owner's screenshot of Ashar 2083 names two things we can predict
    // from first principles. Both are the kind of thing that comes out wrong
    // if a convention is misread, so they are worth pinning.

    test('the Ekadashi of 11 July 2026 is Yogini', () {
      // Hamro Patro lists "योगिनी एकादशी व्रत" that week. Yogini is the
      // *Ashadh* dark-half Ekadashi — but 11 July falls in the dark half of
      // amanta *Jestha*. Naming it from the amanta month would give "Apara",
      // which is a different fast a month away. Nepal names its fasts by the
      // purnimanta month, and this is the test that says so.
      final List<ReligiousDay> days = religiousDaysFor(DateTime(2026, 7, 11));
      expect(
        days.map((ReligiousDay d) => d.nameEn),
        contains('Yogini Ekadashi'),
        reason: 'got ${days.map((ReligiousDay d) => d.nameEn).toList()}',
      );

      // And the trap it avoids: the amanta month really is Jestha.
      final Panchang p = panchangFor(DateTime(2026, 7, 11));
      expect(p.lunarMonthEn, 'Jestha');
      expect(p.paksha, Paksha.krishna);
      expect(p.tithi.nameEn, 'Ekadashi');
    });

    test('Ashar 1 is Mithun Sankranti', () {
      // Hamro Patro marks "मिथुन संक्रान्ति" on Ashar 1, which is 15 June 2026.
      expect(adToBs(DateTime(2026, 6, 15)), const BsDate(2083, 3, 1));
      final List<ReligiousDay> days = religiousDaysFor(DateTime(2026, 6, 15));
      expect(
        days.map((ReligiousDay d) => d.nameEn),
        contains('Mithun Sankranti'),
      );
    });

    test('Pradosh falls on the Trayodashi of 12 July 2026', () {
      // Hamro Patro lists "प्रदोष व्रत" on Ashar 28 = 12 July.
      expect(panchangFor(DateTime(2026, 7, 12)).tithi.nameEn, 'Trayodashi');
      expect(
        religiousDaysFor(
          DateTime(2026, 7, 12),
        ).map((ReligiousDay d) => d.nameEn),
        contains('Pradosh Brata'),
      );
    });
  });

  group('the day card example', () {
    test('25 June 2026 is 11 Ashar 2083, a Thursday, Nirjala Ekadashi', () {
      // Straight from the specification for the day popup. Every part of it is
      // something we work out rather than look up, so all of it is testable.
      final DateTime day = DateTime(2026, 6, 25);

      expect(adToBs(day), const BsDate(2083, 3, 11));
      expect(kWeekdaysEnLong[sundayFirstIndex(day)], 'Thursday');

      final Panchang p = panchangFor(day);
      expect(p.tithi.nameEn, 'Ekadashi');
      expect(p.paksha, Paksha.shukla);

      // Nirjala is the *Jestha* bright-half Ekadashi, and the lunar month here
      // is Jestha — the leap month having pushed it — even though the solar
      // month is Ashar. The two calendars disagree and both are right.
      expect(p.lunarMonthEn, 'Jestha');
      expect(
        religiousDaysFor(day).map((ReligiousDay d) => d.nameEn),
        contains('Nirjala Ekadashi'),
      );
    });
  });

  group('purnimanta naming', () {
    test('the bright half agrees with amanta, the dark half does not', () {
      expect(purnimantaMonth(3, Paksha.shukla), 3);
      expect(purnimantaMonth(3, Paksha.krishna), 4);
      // And it wraps: the dark half of Falgun belongs to Chaitra.
      expect(purnimantaMonth(12, Paksha.krishna), 1);
    });
  });

  group('sankranti', () {
    test('falls on the first of every BS month, and only there', () {
      for (int month = 1; month <= 12; month++) {
        final DateTime first = bsToAd(2083, month, 1);
        final List<ReligiousDay> onFirst = religiousDaysFor(first);
        expect(
          onFirst.any((ReligiousDay d) => d.kind == ReligiousKind.sankranti),
          isTrue,
          reason: 'BS 2083-$month-1 ($first) should be a sankranti',
        );

        final DateTime second = DateTime(
          first.year,
          first.month,
          first.day + 1,
        );
        expect(
          religiousDaysFor(
            second,
          ).any((ReligiousDay d) => d.kind == ReligiousKind.sankranti),
          isFalse,
          reason: 'the second of the month is not a sankranti',
        );
      }
    });

    test('Magh 1 is Makar Sankranti — which is Maghe Sankranti', () {
      // The holiday table has Maghe Sankranti on 15 January 2027, from the
      // gazette. It must land on the day the sun enters Makar.
      final DateTime maghFirst = bsToAd(2084, 10, 1);
      expect(
        religiousDaysFor(maghFirst).map((ReligiousDay d) => d.nameEn),
        contains('Makar Sankranti'),
      );
      // And the 2083 one is the gazette's date.
      expect(dayKey(bsToAd(2083, 10, 1)), '2027-01-15');
    });
  });

  group('zodiac', () {
    test('the sankranti sign agrees with where the sun actually is', () {
      // Two independent routes to the same answer. The sankranti name comes
      // from the BS month number; the sun's rashi comes from its sidereal
      // longitude. If the calendar and the sky disagreed, one of them is wrong.
      for (int month = 1; month <= 12; month++) {
        // A few days in, so the sun is clear of the boundary it just crossed.
        final DateTime midMonth = bsToAd(2083, month, 5);
        expect(
          sunRashiOn(midMonth).index,
          (month - 1) % 12,
          reason: 'BS month $month should have the sun in rashi ${month - 1}',
        );
      }
    });

    test('the moon crosses all twelve rashis in a lunar month', () {
      final Set<int> seen = <int>{};
      DateTime day = DateTime(2026, 7, 1);
      for (int i = 0; i < 28; i++) {
        seen.add(moonRashiOn(day).index);
        day = DateTime(day.year, day.month, day.day + 1);
      }
      expect(seen.length, 12, reason: 'the moon visits every sign in a month');
    });

    test('the moon spends about two and a half days in a sign', () {
      // It covers 360° in 27.3 days, so 30° takes about 2.3.
      int changes = 0;
      DateTime day = DateTime(2026, 7, 1);
      int previous = moonRashiOn(day).index;
      for (int i = 1; i < 28; i++) {
        day = DateTime(day.year, day.month, day.day + 1);
        final int now = moonRashiOn(day).index;
        if (now != previous) {
          changes++;
        }
        previous = now;
      }
      expect(changes, inInclusiveRange(10, 13));
    });

    test('a rashi knows its Western name', () {
      expect(rashiOf(0).nameEn, 'Mesh');
      expect(rashiOf(0).westernName, 'Aries');
      expect(rashiOf(9).nameEn, 'Makar');
      expect(rashiOf(9).westernName, 'Capricorn');
    });
  });

  group('the fortnight', () {
    test('has exactly one Ekadashi in each half of a lunar month', () {
      // Two Ekadashis per lunation, no more and no less — unless a tithi is
      // skipped, which the calendar genuinely does.
      int count = 0;
      DateTime day = DateTime(2026, 8, 1);
      for (int i = 0; i < 29; i++) {
        if (religiousDaysFor(
          day,
        ).any((ReligiousDay d) => d.kind == ReligiousKind.ekadashi)) {
          count++;
        }
        day = DateTime(day.year, day.month, day.day + 1);
      }
      expect(count, inInclusiveRange(1, 2), reason: 'found $count Ekadashis');
    });

    test('Purnima and Aunsi never fall on the same day', () {
      DateTime day = DateTime(2026, 1, 1);
      while (day.year == 2026) {
        final List<ReligiousDay> days = religiousDaysFor(day);
        final bool purnima = days.any(
          (ReligiousDay d) => d.kind == ReligiousKind.purnima,
        );
        final bool aunsi = days.any(
          (ReligiousDay d) => d.kind == ReligiousKind.aunsi,
        );
        expect(purnima && aunsi, isFalse, reason: '$day is both');
        day = DateTime(day.year, day.month, day.day + 1);
      }
    });

    test('Purnima lands on the full moon the panchang found', () {
      // 29 June 2026 is Purnima by tithi.
      expect(
        religiousDaysFor(DateTime(2026, 6, 29)).map((ReligiousDay d) => d.kind),
        contains(ReligiousKind.purnima),
      );
      // And 14 July is Aunsi.
      expect(
        religiousDaysFor(DateTime(2026, 7, 14)).map((ReligiousDay d) => d.kind),
        contains(ReligiousKind.aunsi),
      );
    });
  });

  group('ordinary days', () {
    test('most days carry nothing at all', () {
      int empty = 0;
      DateTime day = DateTime(2026, 8, 1);
      for (int i = 0; i < 31; i++) {
        if (religiousDaysFor(day).isEmpty) {
          empty++;
        }
        day = DateTime(day.year, day.month, day.day + 1);
      }
      // Roughly half a month is unremarkable; a card that lit up every day
      // would be saying nothing.
      expect(empty, greaterThan(10), reason: 'only $empty quiet days in 31');
    });

    test('every day of a year resolves without throwing', () {
      DateTime day = DateTime(2026, 1, 1);
      while (day.year == 2026) {
        expect(() => religiousDaysFor(day), returnsNormally);
        day = DateTime(day.year, day.month, day.day + 1);
      }
    });
  });
}
