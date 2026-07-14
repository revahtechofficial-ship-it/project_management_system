import 'package:flutter_test/flutter_test.dart';
import 'package:revahms_web/core/utils/panchang.dart';

void main() {
  group('the panchang cache', () {
    test('gives the same answer as computing it fresh', () {
      // A cache that is faster and wrong is worse than no cache at all.
      final DateTime day = DateTime(2026, 6, 25);
      final Panchang first = panchangFor(day);
      final Panchang second = panchangFor(day);

      expect(
        identical(first, second),
        isTrue,
        reason: 'should be the same run',
      );
      expect(second.tithi.nameEn, first.tithi.nameEn);
      expect(second.sunrise, first.sunrise);
      expect(second.moonPhase, first.moonPhase);
    });

    test('keys on the day, not the time of day', () {
      // The hover card passes whatever DateTime it has; two moments on the same
      // day must not compute the panchang twice.
      final Panchang morning = panchangFor(DateTime(2026, 6, 25, 3, 15));
      final Panchang evening = panchangFor(DateTime(2026, 6, 25, 22, 45));
      expect(identical(morning, evening), isTrue);
    });

    test('keys on the place as well as the day', () {
      // Two places in Nepal are two different answers, and the cache must not
      // hand one out for the other. Far-west Nepal, where the sun comes up a
      // few minutes after it does in Kathmandu.
      final Panchang kathmandu = panchangFor(DateTime(2026, 6, 25));
      final Panchang farWest = panchangFor(
        DateTime(2026, 6, 25),
        latitude: 29.28,
        longitude: 80.58,
      );

      expect(identical(kathmandu, farWest), isFalse);
      expect(farWest.sunrise, isNot(kathmandu.sunrise));
      // West of Kathmandu, so the sun arrives later on the same clock — but by
      // minutes, not hours.
      expect(farWest.sunrise.isAfter(kathmandu.sunrise), isTrue);
      expect(
        farWest.sunrise.difference(kathmandu.sunrise).inMinutes,
        inInclusiveRange(1, 40),
      );
      // And both are still recognisable Kathmandu-length summer days.
      for (final Panchang p in <Panchang>[kathmandu, farWest]) {
        expect(
          p.sunset.difference(p.sunrise).inHours,
          inInclusiveRange(13, 14),
        );
      }
    });

    test('the almanac is anchored to the Nepali day, and says so', () {
      // Not a bug so much as a boundary: the 24 hours being searched start at
      // midnight in Nepal, so a longitude on the other side of the world stops
      // lining up with that place's own day. This pins the limitation rather
      // than pretending it is not there, so that anyone who does reach for
      // panchangFor(Oslo) finds this test and not a silent wrong answer.
      final Panchang oslo = panchangFor(
        DateTime(2026, 6, 25),
        latitude: 60,
        longitude: 10,
      );
      expect(
        oslo.sunset.isBefore(oslo.sunrise),
        isTrue,
        reason:
            'if this ever passes, panchangFor was made properly global — '
            'good, and the doc comment should go',
      );
    });

    test('does not grow without bound', () {
      // Scrolling through years must not eat the heap. The limit is 512; ask
      // for a thousand distinct days and nothing should break.
      DateTime day = DateTime(2020, 1, 1);
      for (int i = 0; i < 1000; i++) {
        expect(panchangFor(day).tithi.index, inInclusiveRange(1, 30));
        day = DateTime(day.year, day.month, day.day + 1);
      }
      // And the early ones, now evicted, still answer correctly.
      expect(
        panchangFor(DateTime(2020, 1, 1)).tithi.index,
        inInclusiveRange(1, 30),
      );
    });

    test('is fast enough to rebuild on every mouse-move', () {
      // The hover card is rebuilt as the pointer moves, so a day already looked
      // at has to come back essentially free. Warm it, then time a thousand
      // more asks for the same day.
      final DateTime day = DateTime(2026, 7, 9);
      panchangFor(day);

      final Stopwatch watch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        panchangFor(day);
      }
      watch.stop();

      // A cold panchang is a few hundred trig terms plus a scan for sunrise.
      // A thousand warm ones should not come close to a single frame.
      expect(
        watch.elapsedMilliseconds,
        lessThan(16),
        reason: '1000 cached lookups took ${watch.elapsedMilliseconds}ms',
      );
    });
  });
}
