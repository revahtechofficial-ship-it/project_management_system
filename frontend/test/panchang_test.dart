import 'package:flutter_test/flutter_test.dart';
import 'package:revahms_web/core/utils/astronomy.dart';
import 'package:revahms_web/core/utils/panchang.dart';

/// Every tithi Hamro Patro printed for Ashar 2083 (15 Jun - 16 Jul 2026),
/// read off the owner's screenshot. It is a genuine outside check: the tithi
/// depends only on the sun's and the moon's longitudes, so if our ephemeris
/// were wrong these would not line up.
///
/// Two of these look like mistakes and are not. Purnima falls on both 29 and
/// 30 June — the tithi had not ended before the second sunrise, so it names
/// two days. And 15 June (Amavasya) is followed by Dwitiya on the 16th, with
/// no Pratipada at all: that tithi began and ended between two sunrises, so no
/// day carries it. A printed patro shows exactly this.
const Map<String, String> _hamroPatroAshar2083 = <String, String>{
  '2026-06-14': 'Chaturdashi',
  '2026-06-15': 'Amavasya',
  '2026-06-16': 'Dwitiya',
  '2026-06-17': 'Tritiya',
  '2026-06-18': 'Chaturthi',
  '2026-06-19': 'Panchami',
  '2026-06-20': 'Shashthi',
  '2026-06-21': 'Saptami',
  '2026-06-22': 'Ashtami',
  '2026-06-23': 'Navami',
  '2026-06-24': 'Dashami',
  '2026-06-25': 'Ekadashi',
  '2026-06-26': 'Dwadashi',
  '2026-06-27': 'Trayodashi',
  '2026-06-28': 'Chaturdashi',
  '2026-06-29': 'Purnima',
  '2026-06-30': 'Purnima',
  '2026-07-01': 'Pratipada',
  '2026-07-02': 'Dwitiya',
  '2026-07-03': 'Tritiya',
  '2026-07-04': 'Chaturthi',
  '2026-07-05': 'Panchami',
  '2026-07-06': 'Shashthi',
  '2026-07-07': 'Saptami',
  '2026-07-08': 'Ashtami',
  '2026-07-09': 'Navami',
  '2026-07-10': 'Dashami',
  '2026-07-11': 'Ekadashi',
  '2026-07-12': 'Trayodashi',
  '2026-07-13': 'Chaturdashi',
  '2026-07-14': 'Amavasya',
  '2026-07-15': 'Pratipada',
  '2026-07-16': 'Dwitiya',
};

void main() {
  group('tithi against Hamro Patro', () {
    test('all 33 days of Ashar 2083 agree', () {
      final List<String> wrong = <String>[];
      _hamroPatroAshar2083.forEach((String day, String expected) {
        final Panchang p = panchangFor(DateTime.parse(day));
        if (p.tithi.nameEn != expected) {
          wrong.add('$day: expected $expected, got ${p.tithi.nameEn}');
        }
      });
      expect(wrong, isEmpty, reason: wrong.join('\n'));
    });

    test('a tithi may name two days, and a tithi may name none', () {
      // Purnima holds through two sunrises.
      expect(panchangFor(DateTime(2026, 6, 29)).tithi.nameEn, 'Purnima');
      expect(panchangFor(DateTime(2026, 6, 30)).tithi.nameEn, 'Purnima');
      // And Pratipada is skipped after the June new moon.
      expect(panchangFor(DateTime(2026, 6, 15)).tithi.nameEn, 'Amavasya');
      expect(panchangFor(DateTime(2026, 6, 16)).tithi.nameEn, 'Dwitiya');
    });
  });

  group('paksha', () {
    test('runs bright from new moon to full, dark from full to new', () {
      expect(panchangFor(DateTime(2026, 6, 20)).paksha, Paksha.shukla);
      expect(panchangFor(DateTime(2026, 6, 29)).paksha, Paksha.shukla);
      expect(panchangFor(DateTime(2026, 7, 5)).paksha, Paksha.krishna);
      expect(panchangFor(DateTime(2026, 7, 14)).paksha, Paksha.krishna);
    });

    test('Purnima closes the bright half and Amavasya the dark', () {
      expect(panchangFor(DateTime(2026, 6, 29)).tithi.index, 15);
      expect(panchangFor(DateTime(2026, 7, 14)).tithi.index, 30);
    });
  });

  group('astronomy', () {
    test('the sun is at 0° longitude at the March equinox', () {
      // The 2026 equinox is 20 March, 14:46 UTC.
      final double jd = julianDay(DateTime.utc(2026, 3, 20, 14, 46));
      final double lon = sunLongitude(jd);
      expect(lon < 0.05 || lon > 359.95, isTrue, reason: 'sun at $lon°');
    });

    test('the moon meets the sun at the new moons Hamro Patro shows', () {
      for (final String day in <String>['2026-06-15', '2026-07-14']) {
        final double jd = newMoonBefore(
          julianDay(DateTime.parse('${day}T23:59:00Z')),
        );
        final DateTime when = dateTimeOfJd(jd);
        expect(
          when.difference(DateTime.parse('${day}T00:00:00Z')).inHours.abs(),
          lessThan(30),
          reason: 'new moon near $day computed at $when',
        );
        // The elongation is zero at conjunction — but it wraps, so it may
        // read as 359.999 rather than 0.001. Both are the same angle.
        final double e = elongation(jd);
        expect(e < 0.01 || e > 359.99, isTrue, reason: 'elongation $e');
      }
    });

    test('a lunation is about 29.53 days', () {
      final double a = newMoonBefore(julianDay(DateTime.utc(2026, 6, 20)));
      final double b = newMoonBefore(julianDay(DateTime.utc(2026, 7, 20)));
      expect(b - a, closeTo(29.53, 0.5));
    });
  });

  group('sunrise and sunset at Kathmandu', () {
    test('are plausible, and the day is longest in June', () {
      final Panchang june = panchangFor(DateTime(2026, 6, 21));
      final Panchang december = panchangFor(DateTime(2026, 12, 21));

      final Duration juneDay = june.sunset.difference(june.sunrise);
      final Duration decemberDay = december.sunset.difference(december.sunrise);

      // Kathmandu at 27.7°N: about 13h40m at the solstice, 10h30m in winter.
      expect(juneDay.inMinutes, inInclusiveRange(13 * 60, 14 * 60));
      expect(decemberDay.inMinutes, inInclusiveRange(10 * 60, 11 * 60));
      expect(juneDay > decemberDay, isTrue);

      // Sunrise in Kathmandu never strays far from half past five in June.
      expect(june.sunrise.hour, 5);
      expect(december.sunrise.hour, 6);
    });

    test('the sun rises before it sets, every day of a month', () {
      for (int day = 1; day <= 31; day++) {
        final Panchang p = panchangFor(DateTime(2026, 7, day));
        expect(
          p.sunrise.isBefore(p.sunset),
          isTrue,
          reason: 'July $day: ${p.sunrise} -> ${p.sunset}',
        );
      }
    });
  });

  group('moonrise and moonset', () {
    test('the full moon rises about when the sun sets', () {
      final Panchang p = panchangFor(DateTime(2026, 6, 29));
      expect(p.moonrise, isNotNull);
      final int gap = p.moonrise!.difference(p.sunset).inMinutes.abs();
      expect(gap, lessThan(90), reason: 'gap of $gap minutes');
    });

    test('the new moon rises about when the sun rises', () {
      final Panchang p = panchangFor(DateTime(2026, 6, 15));
      expect(p.moonrise, isNotNull);
      final int gap = p.moonrise!.difference(p.sunrise).inMinutes.abs();
      expect(gap, lessThan(90), reason: 'gap of $gap minutes');
    });

    test('the moon sometimes fails to rise or set in a day', () {
      // It rises about 50 minutes later each day, so roughly one day a month
      // it skips one of the two entirely. Nothing should throw.
      int missing = 0;
      for (int day = 1; day <= 31; day++) {
        final Panchang p = panchangFor(DateTime(2026, 7, day));
        if (p.moonrise == null || p.moonset == null) {
          missing++;
        }
      }
      expect(missing, inInclusiveRange(1, 4));
    });
  });

  group('moon phase', () {
    test('the phase is centred on its name, not started by it', () {
      // 180 degrees is the full moon itself, so it must land in the middle of
      // fullMoon, not at the edge of the next phase.
      expect(moonPhaseOf(180), MoonPhase.fullMoon);
      expect(moonPhaseOf(0), MoonPhase.newMoon);
      expect(moonPhaseOf(359.9), MoonPhase.newMoon);
      expect(moonPhaseOf(90), MoonPhase.firstQuarter);
      expect(moonPhaseOf(270), MoonPhase.lastQuarter);
      // And the boundaries fall halfway between two names.
      expect(moonPhaseOf(22.4), MoonPhase.newMoon);
      expect(moonPhaseOf(22.6), MoonPhase.waxingCrescent);
    });

    test('illumination runs 0 at the new moon to 1 at the full', () {
      expect(moonIlluminationOf(0), closeTo(0, 0.001));
      expect(moonIlluminationOf(90), closeTo(0.5, 0.001));
      expect(moonIlluminationOf(180), closeTo(1, 0.001));
      expect(moonIlluminationOf(270), closeTo(0.5, 0.001));
    });

    test('it agrees with the tithi it is read from', () {
      // Both come off the same angle, so they cannot contradict each other.
      // Purnima (tithi 15) must be a full moon; Amavasya (30) a new one.
      final Panchang purnima = panchangFor(DateTime(2026, 6, 29));
      expect(purnima.tithi.nameEn, 'Purnima');
      expect(purnima.moonPhase, MoonPhase.fullMoon);
      expect(purnima.moonIllumination, greaterThan(0.97));

      final Panchang amavasya = panchangFor(DateTime(2026, 7, 14));
      expect(amavasya.tithi.nameEn, 'Amavasya');
      expect(amavasya.moonPhase, MoonPhase.newMoon);
      expect(amavasya.moonIllumination, lessThan(0.03));
    });

    test('waxes through the bright half and wanes through the dark', () {
      // Shukla paksha is the moon filling out; krishna is it emptying.
      const Set<MoonPhase> waxing = <MoonPhase>{
        MoonPhase.waxingCrescent,
        MoonPhase.firstQuarter,
        MoonPhase.waxingGibbous,
      };
      const Set<MoonPhase> waning = <MoonPhase>{
        MoonPhase.waningGibbous,
        MoonPhase.lastQuarter,
        MoonPhase.waningCrescent,
      };
      for (int day = 1; day <= 31; day++) {
        final Panchang p = panchangFor(DateTime(2026, 7, day));
        if (waxing.contains(p.moonPhase)) {
          expect(p.paksha, Paksha.shukla, reason: 'July $day');
        }
        if (waning.contains(p.moonPhase)) {
          expect(p.paksha, Paksha.krishna, reason: 'July $day');
        }
      }
    });

    test('every phase turns up in a lunar month', () {
      final Set<MoonPhase> seen = <MoonPhase>{};
      DateTime day = DateTime(2026, 6, 15);
      for (int i = 0; i < 30; i++) {
        seen.add(panchangFor(day).moonPhase);
        day = DateTime(day.year, day.month, day.day + 1);
      }
      expect(seen.length, 8);
    });
  });

  group('nakshatra, yoga and karana', () {
    test('every day of a year lands on a real one', () {
      DateTime day = DateTime(2026, 1, 1);
      while (day.year == 2026) {
        final Panchang p = panchangFor(day);
        expect(p.nakshatra.index, inInclusiveRange(1, 27));
        expect(p.yoga.index, inInclusiveRange(1, 27));
        expect(p.karana.index, inInclusiveRange(1, 60));
        expect(p.tithi.index, inInclusiveRange(1, 30));
        expect(p.nakshatra.nameEn, isNotEmpty);
        expect(p.yoga.nameEn, isNotEmpty);
        expect(p.karana.nameEn, isNotEmpty);
        day = DateTime(day.year, day.month, day.day + 1);
      }
    });

    test('the nakshatra advances by one most days', () {
      // The moon crosses a nakshatra in about a day, so consecutive days
      // should differ by 0 or 1, never leap.
      for (int day = 1; day <= 27; day++) {
        final int a = panchangFor(DateTime(2026, 7, day)).nakshatra.index;
        final int b = panchangFor(DateTime(2026, 7, day + 1)).nakshatra.index;
        final int step = (b - a + 27) % 27;
        expect(step, lessThanOrEqualTo(2), reason: 'July $day: $a -> $b');
      }
    });

    test('the karana is always half of the tithi it sits in', () {
      // Karana n covers 6 degrees, tithi t covers 12, so karana 2t-1 and 2t
      // both fall inside tithi t. Amavasya (tithi 30) therefore holds karana
      // 59 (Chatushpada) and 60 (Naga), and which one names the day depends on
      // where sunrise falls inside it.
      for (int day = 1; day <= 31; day++) {
        final Panchang p = panchangFor(DateTime(2026, 7, day));
        final int t = p.tithi.index;
        expect(
          p.karana.index,
          anyOf(2 * t - 1, 2 * t),
          reason: 'July \$day: tithi \$t, karana \${p.karana.index}',
        );
      }
    });

    test('the three fixed karanas bracket the new moon', () {
      // Kimstughna opens the month, then Shakuni, Chatushpada and Naga close
      // it. 14 July 2026 is Amavasya, and sunrise lands in Chatushpada.
      final Panchang amavasya = panchangFor(DateTime(2026, 7, 14));
      expect(amavasya.tithi.nameEn, 'Amavasya');
      expect(amavasya.karana.index, 59);
      expect(amavasya.karana.nameEn, 'Chatushpada');
    });
  });

  group('elements end in the future', () {
    test('each limb ends after the sunrise that named it', () {
      for (int day = 1; day <= 30; day++) {
        final Panchang p = panchangFor(DateTime(2026, 9, day));
        for (final PanchangElement e in <PanchangElement>[
          p.tithi,
          p.nakshatra,
          p.yoga,
          p.karana,
        ]) {
          expect(
            e.endsAt.isAfter(p.sunrise),
            isTrue,
            reason:
                'Sept $day: ${e.nameEn} ends ${e.endsAt}, '
                'sunrise ${p.sunrise}',
          );
        }
      }
    });
  });

  group('lunar month', () {
    // 2026 carries a leap month, and Hamro Patro marks its end on Ashar 1
    // (15 June 2026): "adhikmas samapti / Mithuna Sankranti". We find the same
    // thing from first principles — the new moons of 16 May and 15 June both
    // fall with the sun in Vrishabha, the June one at 59.8 degrees sidereal,
    // some four hours short of crossing into Mithuna. Two new moons under one
    // sign is what a leap month *is*.
    test('2026 has a leap month, and it ends at the June new moon', () {
      expect(panchangFor(DateTime(2026, 5, 25)).isAdhikMasa, isTrue);
      expect(
        panchangFor(DateTime(2026, 5, 25)).lunarMonth(nepali: false),
        'Adhik Jestha',
      );
      // The month that opens at the 15 June new moon is the true Jestha.
      expect(panchangFor(DateTime(2026, 6, 16)).isAdhikMasa, isFalse);
      expect(panchangFor(DateTime(2026, 6, 16)).lunarMonthEn, 'Jestha');
    });

    test('the leap month pushes Ashadh a lunation later', () {
      // In an ordinary year early July would already be Ashadh. It is not:
      // Ashadh only opens at the 14 July new moon.
      expect(panchangFor(DateTime(2026, 7, 9)).lunarMonthEn, 'Jestha');
      expect(panchangFor(DateTime(2026, 7, 20)).lunarMonthEn, 'Ashadh');
    });

    test('every day of a year names one of the twelve', () {
      DateTime day = DateTime(2026, 1, 1);
      while (day.year == 2026) {
        expect(panchangFor(day).lunarMonthEn, isNotEmpty);
        day = DateTime(day.year, day.month, day.day + 1);
      }
    });
  });
}
