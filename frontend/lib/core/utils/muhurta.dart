import 'nepali_calendar.dart';
import 'panchang.dart';

// The day's auspicious and inauspicious windows (AGENTS.md §1 `core/utils`).
//
// These are not astronomy — they are arithmetic on the length of the day. The
// stretch from sunrise to sunset is cut into eight equal parts, and which part
// falls to Rahu, to Gulika and to Yama depends only on the weekday. So the
// windows shift through the year with the sunrise, but the rule behind them is
// a fixed table.
//
// Two things follow, and both are worth knowing. The windows are shorter in
// winter, because the day is. And they are exact — unlike a marriage saait,
// which is a judgement published by a panchang committee and cannot be
// computed at all. Those live in the `muhurats` table instead.

/// Which of the eight parts of the day falls to Rahu, by weekday (Sunday = 0).
///
/// One-based, as every published table gives it: on a Sunday Rahu takes the
/// eighth and last part of the day, on a Monday the second.
const List<int> _rahuPart = <int>[8, 2, 7, 5, 6, 4, 3];

/// Gulika (also Mandi) walks backwards through the parts: the first on
/// Saturday, the seventh on Sunday.
const List<int> _gulikaPart = <int>[7, 6, 5, 4, 3, 2, 1];

/// Yamaganda.
const List<int> _yamagandaPart = <int>[5, 4, 3, 2, 1, 7, 6];

/// A window of time, and whether it is one to use or one to avoid.
class Muhurta {
  const Muhurta({
    required this.nameEn,
    required this.nameNe,
    required this.start,
    required this.end,
    required this.auspicious,
  });

  final String nameEn;
  final String nameNe;

  /// Both in Nepal time.
  final DateTime start;
  final DateTime end;

  /// True for a window to seek out, false for one to avoid.
  final bool auspicious;

  String name({required bool nepali}) => nepali ? nameNe : nameEn;

  Duration get length => end.difference(start);

  /// Whether [moment] falls inside the window.
  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(end);

  @override
  String toString() => '$nameEn ($start - $end)';
}

/// The day's windows, in the order they occur.
class DayMuhurtas {
  const DayMuhurtas({
    required this.date,
    required this.rahuKaal,
    required this.gulikaKaal,
    required this.yamaganda,
    required this.abhijit,
    required this.sunrise,
    required this.sunset,
  });

  final DateTime date;

  /// The three to avoid.
  final Muhurta rahuKaal;
  final Muhurta gulikaKaal;
  final Muhurta yamaganda;

  /// The one to seek — but see [hasAbhijit].
  final Muhurta abhijit;

  final DateTime sunrise;
  final DateTime sunset;

  /// Abhijit is held not to apply on a Wednesday. Rather than quietly drop it,
  /// the window is still computed and this says whether to honour it.
  bool get hasAbhijit => sundayFirstIndex(date) != 3;

  /// Everything, earliest first.
  List<Muhurta> get all {
    final List<Muhurta> list = <Muhurta>[
      rahuKaal,
      gulikaKaal,
      yamaganda,
      if (hasAbhijit) abhijit,
    ]..sort((Muhurta a, Muhurta b) => a.start.compareTo(b.start));
    return list;
  }

  /// The windows to avoid, earliest first.
  List<Muhurta> get inauspicious =>
      all.where((Muhurta m) => !m.auspicious).toList();

  /// The window [moment] falls in, if any. When Abhijit overlaps one of the
  /// three — which happens, since Rahu takes the middle of the day on a
  /// Wednesday — the inauspicious one is reported, because that is the reading
  /// a patro gives.
  Muhurta? at(DateTime moment) {
    for (final Muhurta m in inauspicious) {
      if (m.contains(moment)) {
        return m;
      }
    }
    if (hasAbhijit && abhijit.contains(moment)) {
      return abhijit;
    }
    return null;
  }

  @override
  String toString() => 'DayMuhurtas(${dayKey(date)})';
}

/// The windows for [date], reckoned at Kathmandu.
DayMuhurtas muhurtasFor(
  DateTime date, {
  double latitude = kKathmanduLatitude,
  double longitude = kKathmanduLongitude,
}) {
  final Panchang p = panchangFor(
    date,
    latitude: latitude,
    longitude: longitude,
  );
  final DateTime sunrise = p.sunrise;
  final DateTime sunset = p.sunset;
  final int weekday = sundayFirstIndex(date);

  // An eighth of the daylight — the unit all three inauspicious windows are
  // measured in. It is about 90 minutes in June and about 79 in December.
  final Duration daylight = sunset.difference(sunrise);
  final int eighthMs = daylight.inMilliseconds ~/ 8;

  Muhurta part(int oneBasedPart, String en, String ne) {
    final DateTime start = sunrise.add(
      Duration(milliseconds: eighthMs * (oneBasedPart - 1)),
    );
    return Muhurta(
      nameEn: en,
      nameNe: ne,
      start: start,
      end: start.add(Duration(milliseconds: eighthMs)),
      auspicious: false,
    );
  }

  // Abhijit is the eighth of the fifteen muhurtas of the day — the one that
  // straddles local noon.
  final int fifteenthMs = daylight.inMilliseconds ~/ 15;
  final DateTime abhijitStart = sunrise.add(
    Duration(milliseconds: fifteenthMs * 7),
  );

  return DayMuhurtas(
    date: dateOnly(date),
    rahuKaal: part(_rahuPart[weekday], 'Rahu Kaal', 'राहु काल'),
    gulikaKaal: part(_gulikaPart[weekday], 'Gulika Kaal', 'गुलिक काल'),
    yamaganda: part(_yamagandaPart[weekday], 'Yamaganda', 'यमगण्ड'),
    abhijit: Muhurta(
      nameEn: 'Abhijit Muhurat',
      nameNe: 'अभिजित मुहूर्त',
      start: abhijitStart,
      end: abhijitStart.add(Duration(milliseconds: fifteenthMs)),
      auspicious: true,
    ),
    sunrise: sunrise,
    sunset: sunset,
  );
}
