import '../enums/sprint_status.dart';

/// A time-boxed iteration of tasks, from `GET /api/v1/sprints` (with rolled-up
/// task/point counts). Manual JSON serialization per AGENTS.md §9.
class Sprint {
  final int id;
  final String name;
  final String goal;
  final SprintStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int taskCount;
  final int doneCount;
  final int totalPoints;
  final int donePoints;

  const Sprint({
    required this.id,
    this.name = '',
    this.goal = '',
    this.status = SprintStatus.planned,
    this.startDate,
    this.endDate,
    this.taskCount = 0,
    this.doneCount = 0,
    this.totalPoints = 0,
    this.donePoints = 0,
  });

  /// Fraction of story points completed, in `0.0`–`1.0`.
  double get pointsProgress => totalPoints == 0 ? 0 : donePoints / totalPoints;

  /// Whole days until the end date (negative once past), or null when unset.
  int? get daysLeft {
    if (endDate == null) {
      return null;
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return endDate!.toLocal().difference(today).inDays;
  }

  factory Sprint.fromJson(Map<String, dynamic> json) => Sprint(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    goal: json['goal'] as String? ?? '',
    status: SprintStatus.fromJson(json['status'] as String? ?? 'planned'),
    startDate: json['start_date'] == null
        ? null
        : DateTime.parse(json['start_date'] as String),
    endDate: json['end_date'] == null
        ? null
        : DateTime.parse(json['end_date'] as String),
    taskCount: json['task_count'] as int? ?? 0,
    doneCount: json['done_count'] as int? ?? 0,
    totalPoints: json['total_points'] as int? ?? 0,
    donePoints: json['done_points'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'goal': goal,
    'status': status.toJson(),
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'task_count': taskCount,
    'done_count': doneCount,
    'total_points': totalPoints,
    'done_points': donePoints,
  };

  @override
  String toString() => 'Sprint(id: $id, name: $name, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sprint &&
          other.id == id &&
          other.name == name &&
          other.goal == goal &&
          other.status == status &&
          other.startDate == startDate &&
          other.endDate == endDate &&
          other.taskCount == taskCount &&
          other.doneCount == doneCount &&
          other.totalPoints == totalPoints &&
          other.donePoints == donePoints;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    goal,
    status,
    startDate,
    endDate,
    taskCount,
    doneCount,
    totalPoints,
    donePoints,
  );
}
