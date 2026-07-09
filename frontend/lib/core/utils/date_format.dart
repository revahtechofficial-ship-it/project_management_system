// Lightweight date helpers (AGENTS.md §1 `core/utils`). The app has no `intl`
// dependency, so formatting is done by hand against fixed English labels.

const List<String> _weekdaysShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<String> _weekdaysLong = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const List<String> _monthsLong = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const List<String> _monthsShort = <String>[
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

/// Short weekday label, e.g. `Mon`.
String weekdayShort(int weekday) => _weekdaysShort[(weekday - 1) % 7];

/// Full date, e.g. `Wednesday, 11 June 2026`.
String formatLongDate(DateTime d) =>
    '${_weekdaysLong[(d.weekday - 1) % 7]}, ${d.day} '
    '${_monthsLong[d.month - 1]} ${d.year}';

/// Compact date, e.g. `11 Jun`.
String shortDate(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

/// Short month + year, e.g. `Jun 2026`.
String monthYear(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

/// `YYYY-MM-DD` for sending date-only values to the API; null passes through.
String? dateParam(DateTime? d) {
  if (d == null) {
    return null;
  }
  final String mm = d.month.toString().padLeft(2, '0');
  final String dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// Whether [a] and [b] fall on the same calendar day.
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Coarse "time ago" label, e.g. `just now`, `5m ago`, `3d ago`.
String relativeTime(DateTime time) {
  final Duration diff = DateTime.now().difference(time.toLocal());
  if (diff.inSeconds < 60) {
    return 'just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  }
  return '${(diff.inDays / 7).floor()}w ago';
}
