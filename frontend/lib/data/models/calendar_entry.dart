import '../enums/calendar_entry_kind.dart';

/// A personal calendar entry: a note, a birthday, an anniversary, a meeting.
///
/// Private to its owner — the API never returns anyone else's. Manual JSON per
/// AGENTS.md §9.
class CalendarEntry {
  final int id;

  /// The day it was recorded for: the birth date, the day of the meeting.
  final DateTime date;

  final CalendarEntryKind kind;
  final String title;
  final String note;

  /// `HH:MM`, or empty for an all-day entry.
  final String startTime;
  final String endTime;

  final RepeatIn repeatIn;

  /// Days of notice, or null for no reminder.
  final int? remindDays;

  /// The next day it falls on, worked out by the server — which is the only
  /// place that can, since a BS recurrence needs the conversion table.
  final DateTime? nextOccurs;

  const CalendarEntry({
    required this.id,
    required this.date,
    this.kind = CalendarEntryKind.note,
    this.title = '',
    this.note = '',
    this.startTime = '',
    this.endTime = '',
    this.repeatIn = RepeatIn.none,
    this.remindDays,
    this.nextOccurs,
  });

  bool get isAllDay => startTime.isEmpty;

  /// `09:15 – 10:00`, `09:15`, or `All day`.
  String window({required bool nepali}) {
    if (isAllDay) {
      return nepali ? 'दिनभर' : 'All day';
    }
    if (endTime.isEmpty) {
      return startTime;
    }
    return '$startTime – $endTime';
  }

  /// The day this entry belongs on in the calendar grid: its next occurrence
  /// if it repeats, otherwise the day it was recorded for.
  DateTime get shownOn => repeatIn.repeats ? (nextOccurs ?? date) : date;

  /// How many years old this anniversary is on [when], or null when the entry
  /// does not repeat. A birthday recorded in 1994 is worth a number.
  int? yearsAt(DateTime when) {
    if (!repeatIn.repeats) {
      return null;
    }
    final int years = when.year - date.year;
    return years > 0 ? years : null;
  }

  static String _str(Map<String, dynamic> json, String key) =>
      json[key] as String? ?? '';

  static DateTime? _date(Map<String, dynamic> json, String key) {
    final String raw = _str(json, key);
    return raw.isEmpty ? null : DateTime.parse(raw);
  }

  factory CalendarEntry.fromJson(Map<String, dynamic> json) => CalendarEntry(
    id: json['id'] as int,
    date: DateTime.parse(json['date'] as String),
    kind: CalendarEntryKind.fromJson(_str(json, 'kind')),
    title: _str(json, 'title'),
    note: _str(json, 'note'),
    startTime: _str(json, 'start_time'),
    endTime: _str(json, 'end_time'),
    repeatIn: RepeatIn.fromJson(_str(json, 'repeat_in')),
    remindDays: json['remind_days'] as int?,
    nextOccurs: _date(json, 'next_occurs'),
  );

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'date': _ymd(date),
    'kind': kind.toJson(),
    'title': title,
    'note': note,
    'start_time': startTime,
    'end_time': endTime,
    'repeat_in': repeatIn.toJson(),
    'remind_days': remindDays,
    'next_occurs': nextOccurs == null ? '' : _ymd(nextOccurs!),
  };

  @override
  String toString() => 'CalendarEntry(id: $id, ${kind.name}, $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEntry &&
          other.id == id &&
          other.date == date &&
          other.kind == kind &&
          other.title == title &&
          other.note == note &&
          other.startTime == startTime &&
          other.endTime == endTime &&
          other.repeatIn == repeatIn &&
          other.remindDays == remindDays &&
          other.nextOccurs == nextOccurs;

  @override
  int get hashCode => Object.hash(
    id,
    date,
    kind,
    title,
    note,
    startTime,
    endTime,
    repeatIn,
    remindDays,
    nextOccurs,
  );
}
