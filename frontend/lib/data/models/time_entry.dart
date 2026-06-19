/// A logged time entry (a timer session or a manual entry), from
/// `/api/v1/time-entries`. Manual JSON serialization per AGENTS.md §9.
class TimeEntry {
  final int id;
  final int userId;
  final String userName;
  final int? taskId;
  final String taskTitle;
  final int minutes;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String description;
  final bool billable;
  final bool running;

  const TimeEntry({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.userName = '',
    this.taskId,
    this.taskTitle = '',
    this.minutes = 0,
    this.endedAt,
    this.description = '',
    this.billable = false,
    this.running = false,
  });

  /// A human-readable duration, e.g. `2h 15m` or `45m`.
  String get durationLabel => formatMinutes(minutes);

  /// A label for what the entry is about: its task, else its note, else dash.
  String get subject => taskTitle.isNotEmpty
      ? taskTitle
      : (description.isNotEmpty ? description : 'General');

  static String formatMinutes(int total) {
    if (total <= 0) {
      return '0m';
    }
    final int h = total ~/ 60;
    final int m = total % 60;
    if (h == 0) {
      return '${m}m';
    }
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  factory TimeEntry.fromJson(Map<String, dynamic> json) => TimeEntry(
    id: json['id'] as int,
    userId: json['user_id'] as int,
    userName: json['user_name'] as String? ?? '',
    taskId: json['task_id'] as int?,
    taskTitle: json['task_title'] as String? ?? '',
    minutes: json['minutes'] as int? ?? 0,
    startedAt: DateTime.parse(json['started_at'] as String),
    endedAt: json['ended_at'] == null
        ? null
        : DateTime.parse(json['ended_at'] as String),
    description: json['description'] as String? ?? '',
    billable: json['billable'] as bool? ?? false,
    running: json['running'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'task_id': taskId,
    'task_title': taskTitle,
    'minutes': minutes,
    'started_at': startedAt.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
    'description': description,
    'billable': billable,
    'running': running,
  };

  @override
  String toString() =>
      'TimeEntry(id: $id, minutes: $minutes, running: $running)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeEntry &&
          other.id == id &&
          other.minutes == minutes &&
          other.taskId == taskId &&
          other.startedAt == startedAt &&
          other.endedAt == endedAt &&
          other.description == description &&
          other.billable == billable &&
          other.running == running;

  @override
  int get hashCode => Object.hash(
    id,
    minutes,
    taskId,
    startedAt,
    endedAt,
    description,
    billable,
    running,
  );
}
