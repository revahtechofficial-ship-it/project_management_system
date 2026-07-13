import 'date_format.dart';
import 'nepali_calendar.dart';

// Turning what somebody typed into a date (AGENTS.md §1 `core/utils`).
//
// The awkward part is that a bare "2083-03-25" is genuinely ambiguous. BS runs
// 1970-2250 and AD 1900-2100, so the two ranges overlap across a century and a
// half: 2026 is a real AD year *and* a real BS year, and nothing in the string
// says which was meant. Guessing would be wrong roughly half the time.
//
// So this does not guess. It returns every reading that parses, says which
// calendar each came from, and lets the caller show them both. When only one
// reading is possible — "2083" is not an AD year anybody means, "1995" is not
// a BS one — only one comes back.

/// A date somebody might have meant, and the calendar it was read in.
class DateMatch {
  const DateMatch({
    required this.date,
    required this.readAs,
    required this.query,
  });

  /// Always the Gregorian day, whichever calendar it was typed in.
  final DateTime date;

  /// The calendar the query was read against.
  final DateCalendar readAs;

  /// What was typed, so a result can echo it back.
  final String query;

  @override
  String toString() => 'DateMatch(${dayKey(date)} as ${readAs.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateMatch && other.date == date && other.readAs == readAs;

  @override
  int get hashCode => Object.hash(date, readAs);
}

/// Which calendar a query was read in.
enum DateCalendar {
  bs,
  ad;

  String get label => this == DateCalendar.bs ? 'Bikram Sambat' : 'Gregorian';
  String get labelNe =>
      this == DateCalendar.bs ? 'विक्रम संवत्' : 'ईस्वी संवत्';
  String get short => this == DateCalendar.bs ? 'BS' : 'AD';
}

const Map<String, int> _neDigitValues = <String, int>{
  '०': 0,
  '१': 1,
  '२': 2,
  '३': 3,
  '४': 4,
  '५': 5,
  '६': 6,
  '७': 7,
  '८': 8,
  '९': 9,
};

/// Rewrites Devanagari digits as ASCII, so `२०८३` parses like `2083`.
String asciiDigits(String input) {
  final StringBuffer out = StringBuffer();
  for (final String ch in input.split('')) {
    out.write(_neDigitValues[ch]?.toString() ?? ch);
  }
  return out.toString();
}

/// The BS month a word names, or 0. Matches a prefix, so "asa" finds Ashar and
/// "बै" finds Baishakh — people do not finish typing month names.
int bsMonthFromWord(String word) {
  final String w = word.trim().toLowerCase();
  if (w.isEmpty) {
    return 0;
  }
  for (int m = 1; m <= 12; m++) {
    if (kBsMonthsEn[m].toLowerCase().startsWith(w) ||
        kBsMonthsNe[m].startsWith(word.trim())) {
      return m;
    }
  }
  // The spellings people actually type.
  const Map<String, int> aliases = <String, int>{
    'baisakh': 1,
    'bhaisakh': 1,
    'vaishakh': 1,
    'baishak': 1,
    'jeth': 2,
    'jestha': 2,
    'jyestha': 2,
    'asar': 3,
    'ashadh': 3,
    'asadh': 3,
    'ashar': 3,
    'sawan': 4,
    'shrawan': 4,
    'srawan': 4,
    'saun': 4,
    'bhadau': 5,
    'bhadra': 5,
    'bhado': 5,
    'asoj': 6,
    'ashwin': 6,
    'aswin': 6,
    'ashoj': 6,
    'kartik': 7,
    'kattik': 7,
    'mangsir': 8,
    'mangshir': 8,
    'marga': 8,
    'poush': 9,
    'push': 9,
    'pus': 9,
    'paush': 9,
    'magh': 10,
    'mangh': 10,
    'falgun': 11,
    'phalgun': 11,
    'fagun': 11,
    'chaitra': 12,
    'chait': 12,
    'chaet': 12,
  };
  for (final MapEntry<String, int> e in aliases.entries) {
    if (e.key.startsWith(w)) {
      return e.value;
    }
  }
  return 0;
}

/// The Gregorian month a word names, or 0. Prefix-matched, as above.
int adMonthFromWord(String word) {
  final String w = word.trim().toLowerCase();
  if (w.length < 3) {
    return 0;
  }
  for (int m = 1; m <= 12; m++) {
    if (monthLong(m).toLowerCase().startsWith(w) ||
        kAdMonthsShort[m].toLowerCase() == w) {
      return m;
    }
  }
  return 0;
}

/// Whether a year is plausibly meant as BS or as AD, or as either.
bool _plausibleBs(int year) =>
    year >= kBsPickerMinYear && year <= kBsPickerMaxYear;
bool _plausibleAd(int year) => year >= 1944 && year <= 2043;

/// Builds a match, dropping it if the date does not exist — 32 Falgun does not,
/// and neither does 31 February.
DateMatch? _bs(int year, int month, int day, String query) {
  if (!_plausibleBs(year) || month < 1 || month > 12) {
    return null;
  }
  final int length = bsMonthLength(year, month);
  if (length == 0 || day < 1 || day > length) {
    return null;
  }
  return DateMatch(
    date: bsToAd(year, month, day),
    readAs: DateCalendar.bs,
    query: query,
  );
}

DateMatch? _ad(int year, int month, int day, String query) {
  if (!_plausibleAd(year) || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final DateTime made = DateTime(year, month, day);
  // DateTime rolls 31 February over into March. If it moved, it was not real.
  if (made.month != month || made.day != day) {
    return null;
  }
  return DateMatch(date: made, readAs: DateCalendar.ad, query: query);
}

/// Every date [query] could mean, soonest first.
///
/// Returns both readings of an ambiguous year rather than choosing one. Empty
/// when nothing parses, which is the common case — most searches are for a
/// festival, not a date.
List<DateMatch> searchDates(String query) {
  final String raw = query.trim();
  if (raw.isEmpty) {
    return const <DateMatch>[];
  }
  final String q = asciiDigits(raw);
  final List<DateMatch> found = <DateMatch>[];

  void add(DateMatch? m) {
    if (m != null && !found.contains(m)) {
      found.add(m);
    }
  }

  // yyyy-mm-dd, yyyy/mm/dd, dd-mm-yyyy, dd/mm/yyyy.
  final RegExp numeric = RegExp(r'^(\d{1,4})[-/.](\d{1,2})[-/.](\d{1,4})$');
  final RegExpMatch? n = numeric.firstMatch(q);
  if (n != null) {
    final int a = int.parse(n.group(1)!);
    final int b = int.parse(n.group(2)!);
    final int c = int.parse(n.group(3)!);
    if (a > 31) {
      // Year first.
      add(_bs(a, b, c, raw));
      add(_ad(a, b, c, raw));
    } else if (c > 31) {
      // Year last: day, month, year.
      add(_bs(c, b, a, raw));
      add(_ad(c, b, a, raw));
    }
  }

  // A month name, with a day and/or a year in any order: "25 asar 2083",
  // "asar 25", "9 july 2026", "july 2026".
  final List<String> words = q
      .replaceAll(RegExp(r'[,]'), ' ')
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList();
  if (words.length >= 2 && words.length <= 3) {
    final List<int> numbers = <int>[
      for (final String w in words)
        if (int.tryParse(w) != null) int.parse(w),
    ];
    final List<String> names = <String>[
      for (final String w in words)
        if (int.tryParse(w) == null) w,
    ];
    if (names.length == 1) {
      final String name = names.first;
      final int bsMonth = bsMonthFromWord(name);
      final int adMonth = adMonthFromWord(name);

      int? day;
      int? year;
      for (final int v in numbers) {
        if (v > 31) {
          year ??= v;
        } else {
          day ??= v;
        }
      }

      if (bsMonth != 0) {
        final BsDate today = bsToday();
        add(_bs(year ?? today.year, bsMonth, day ?? 1, raw));
      }
      if (adMonth != 0) {
        add(_ad(year ?? DateTime.now().year, adMonth, day ?? 1, raw));
      }
    }
  }

  // A bare year: offer the first of it, so "2084" lands somewhere useful.
  final int? bare = int.tryParse(q);
  if (bare != null && q.length == 4) {
    add(_bs(bare, 1, 1, raw));
    add(_ad(bare, 1, 1, raw));
  }

  found.sort((DateMatch a, DateMatch b) => a.date.compareTo(b.date));
  return found;
}
