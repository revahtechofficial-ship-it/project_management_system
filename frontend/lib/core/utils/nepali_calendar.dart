import 'package:nepali_utils/nepali_utils.dart';

// Bikram Sambat (BS) calendar helpers (AGENTS.md §1 `core/utils`).
//
// BS month lengths vary year to year, so the conversion needs a lookup table
// rather than a formula. We take that table from `nepali_utils` — but only
// through `NepaliDateTime(y, m, d).toDateTime()` (BS -> AD), which is correct.
//
// The package's opposite direction (`DateTime.toNepaliDateTime()`, and
// therefore `NepaliDateTime.now()`) is off by one day: it maps 2024-04-13 to
// 2081-01-02 even though it maps 2081-01-01 back to 2024-04-13. See
// test/nepali_calendar_test.dart. So AD -> BS is derived here by searching the
// trustworthy direction, and the buggy one is never used.

/// A date in the Bikram Sambat calendar.
class BsDate {
  const BsDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  @override
  String toString() => '$year-$month-$day';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BsDate &&
          other.year == year &&
          other.month == month &&
          other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// BS month names in Nepali, indexed 1–12.
const List<String> kBsMonthsNe = <String>[
  '',
  'बैशाख',
  'जेठ',
  'असार',
  'साउन',
  'भदौ',
  'असोज',
  'कार्तिक',
  'मंसिर',
  'पुष',
  'माघ',
  'फागुन',
  'चैत',
];

/// BS month names transliterated, indexed 1–12.
const List<String> kBsMonthsEn = <String>[
  '',
  'Baishakh',
  'Jestha',
  'Ashar',
  'Shrawan',
  'Bhadra',
  'Ashwin',
  'Kartik',
  'Mangsir',
  'Poush',
  'Magh',
  'Falgun',
  'Chaitra',
];

/// Short weekday names, Sunday first (the Nepali week starts on Sunday).
const List<String> kWeekdaysNe = <String>[
  'आइत',
  'सोम',
  'मंगल',
  'बुध',
  'बिही',
  'शुक्र',
  'शनि',
];

const List<String> kWeekdaysEn = <String>[
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

/// Full weekday names, Sunday first, for the calendar's column headings.
const List<String> kWeekdaysNeLong = <String>[
  'आइतवार',
  'सोमवार',
  'मङ्गलवार',
  'बुधवार',
  'बिहीवार',
  'शुक्रवार',
  'शनिवार',
];

const List<String> kWeekdaysEnLong = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// Gregorian month abbreviations, indexed 1–12.
const List<String> kAdMonthsShort = <String>[
  '',
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _neDigits = <String>[
  '०',
  '१',
  '२',
  '३',
  '४',
  '५',
  '६',
  '७',
  '८',
  '९',
];

/// Renders [value]'s digits in Devanagari (e.g. `2083` → `२०८३`).
String toNepaliDigits(Object value) =>
    value.toString().split('').map((String c) {
      final int? d = int.tryParse(c);
      return d == null ? c : _neDigits[d];
    }).join();

/// The digits of [value] in Devanagari when [nepali], otherwise unchanged.
String localDigits(Object value, {required bool nepali}) =>
    nepali ? toNepaliDigits(value) : '$value';

/// Strips any time component so day arithmetic is exact.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole days from [from] to [to], ignoring time zones.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Whether two dates fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The Gregorian date of a Bikram Sambat date.
DateTime bsToAd(int year, int month, int day) =>
    dateOnly(NepaliDateTime(year, month, day).toDateTime());

/// The Bikram Sambat date of a Gregorian date.
///
/// Derived by searching [bsToAd], because the package's own AD→BS conversion
/// is a day out (see the file header).
BsDate adToBs(DateTime ad) {
  final DateTime target = dateOnly(ad);
  // A BS year runs ahead of the Gregorian year by 56 (Jan–mid Apr) or 57.
  for (int year = target.year + 56; year <= target.year + 57; year++) {
    final DateTime yearStart = bsToAd(year, 1, 1);
    final DateTime nextYearStart = bsToAd(year + 1, 1, 1);
    if (target.isBefore(yearStart) || !target.isBefore(nextYearStart)) {
      continue;
    }
    for (int month = 12; month >= 1; month--) {
      final DateTime monthStart = bsToAd(year, month, 1);
      if (!target.isBefore(monthStart)) {
        return BsDate(year, month, daysBetween(monthStart, target) + 1);
      }
    }
  }
  throw ArgumentError('date $ad is outside the supported BS range');
}

/// Today in the Bikram Sambat calendar.
BsDate bsToday() => adToBs(DateTime.now());

/// The number of days in a BS month.
int bsMonthLength(int year, int month) {
  final DateTime start = bsToAd(year, month, 1);
  final DateTime nextStart = month == 12
      ? bsToAd(year + 1, 1, 1)
      : bsToAd(year, month + 1, 1);
  return daysBetween(start, nextStart);
}

/// Every Gregorian date that falls inside the given BS month, in order.
List<DateTime> bsMonthDays(int year, int month) {
  final DateTime start = bsToAd(year, month, 1);
  final int length = bsMonthLength(year, month);
  return <DateTime>[
    for (int i = 0; i < length; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
}

/// The BS month [delta] months away from `(year, month)`.
BsDate addBsMonths(int year, int month, int delta) {
  int y = year;
  int m = month + delta;
  while (m > 12) {
    m -= 12;
    y++;
  }
  while (m < 1) {
    m += 12;
    y--;
  }
  return BsDate(y, m, 1);
}

/// The zero-based column (Sunday = 0) a Gregorian date falls in.
int sundayFirstIndex(DateTime date) => date.weekday % 7;

/// The BS month label, e.g. `असार २०८३` or `Ashar 2083`.
String bsMonthLabel(int year, int month, {required bool nepali}) => nepali
    ? '${kBsMonthsNe[month]} ${toNepaliDigits(year)}'
    : '${kBsMonthsEn[month]} $year';

/// The Gregorian span a BS month covers, e.g. `Jun – Jul 2026`.
String adRangeLabel(List<DateTime> days) {
  if (days.isEmpty) {
    return '';
  }
  final DateTime first = days.first;
  final DateTime last = days.last;
  if (first.month == last.month && first.year == last.year) {
    return '${kAdMonthsShort[first.month]} ${first.year}';
  }
  final String head = first.year == last.year
      ? kAdMonthsShort[first.month]
      : '${kAdMonthsShort[first.month]} ${first.year}';
  return '$head – ${kAdMonthsShort[last.month]} ${last.year}';
}

/// A `yyyy-mm-dd` key for grouping events by Gregorian day.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// A one-line date for an event list, e.g. `Fri, 28 Aug 2026` in English or
/// `शुक्र, १२ भदौ २०८३` in Nepali (which counts in the BS calendar).
String eventDateLine(DateTime ad, {required bool nepali}) {
  final int col = sundayFirstIndex(ad);
  if (!nepali) {
    return '${kWeekdaysEn[col]}, ${ad.day} '
        '${kAdMonthsShort[ad.month]} ${ad.year}';
  }
  final BsDate bs = adToBs(ad);
  return '${kWeekdaysNe[col]}, ${toNepaliDigits(bs.day)} '
      '${kBsMonthsNe[bs.month]} ${toNepaliDigits(bs.year)}';
}

/// A full date line in both calendars, e.g.
/// `असार २५, २०८३ · बिही, 9 Jul 2026`.
String fullDualDate(DateTime ad, {required bool nepali}) {
  final BsDate bs = adToBs(ad);
  final String bsPart = nepali
      ? '${kBsMonthsNe[bs.month]} ${toNepaliDigits(bs.day)}, '
            '${toNepaliDigits(bs.year)}'
      : '${kBsMonthsEn[bs.month]} ${bs.day}, ${bs.year}';
  final int col = sundayFirstIndex(ad);
  final String weekday = nepali ? kWeekdaysNe[col] : kWeekdaysEn[col];
  return '$bsPart · $weekday, ${ad.day} ${kAdMonthsShort[ad.month]} ${ad.year}';
}
