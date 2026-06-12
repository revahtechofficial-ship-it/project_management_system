/// A task activity entry, from `GET /api/v1/tasks/{id}/activity`. Manual JSON
/// serialization per AGENTS.md §9.
class Activity {
  final int id;
  final int taskId;
  final int? actorId;
  final String? actorName;
  final String action;
  final String detail;
  final DateTime createdAt;

  const Activity({
    required this.id,
    required this.taskId,
    required this.createdAt,
    this.actorId,
    this.actorName,
    this.action = '',
    this.detail = '',
  });

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as int,
        taskId: json['task_id'] as int,
        actorId: json['actor_id'] as int?,
        actorName: json['actor_name'] as String?,
        action: json['action'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'task_id': taskId,
        'actor_id': actorId,
        'actor_name': actorName,
        'action': action,
        'detail': detail,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'Activity(id: $id, action: $action)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Activity &&
          other.id == id &&
          other.taskId == taskId &&
          other.actorId == actorId &&
          other.actorName == actorName &&
          other.action == action &&
          other.detail == detail &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
      id, taskId, actorId, actorName, action, detail, createdAt);
}
