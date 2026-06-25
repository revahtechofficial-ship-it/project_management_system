import '../enums/availability_kind.dart';

/// A stretch of days a team member is unavailable (Availability Tracking).
/// [startDate] and [endDate] are inclusive, date-only values. Manual JSON
/// serialization per AGENTS.md §9.
class AvailabilityEntry {
  final int id;
  final int userId;
  final String userName;
  final DateTime startDate;
  final DateTime endDate;
  final AvailabilityKind kind;
  final String note;

  const AvailabilityEntry({
    required this.id,
    required this.userId,
    required this.startDate,
    required this.endDate,
    this.userName = '',
    this.kind = AvailabilityKind.other,
    this.note = '',
  });

  /// Whether [day] (date-only) falls within this entry, inclusive.
  bool covers(DateTime day) {
    final DateTime d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  factory AvailabilityEntry.fromJson(Map<String, dynamic> json) =>
      AvailabilityEntry(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        userName: json['user_name'] as String? ?? '',
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        kind: AvailabilityKind.fromJson(json['kind'] as String? ?? ''),
        note: json['note'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'start_date': _date(startDate),
    'end_date': _date(endDate),
    'kind': kind.toJson(),
    'note': note,
  };

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  String toString() =>
      'AvailabilityEntry(id: $id, userId: $userId, kind: $kind)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvailabilityEntry &&
          other.id == id &&
          other.userId == userId &&
          other.userName == userName &&
          other.startDate == startDate &&
          other.endDate == endDate &&
          other.kind == kind &&
          other.note == note;

  @override
  int get hashCode =>
      Object.hash(id, userId, userName, startDate, endDate, kind, note);
}
