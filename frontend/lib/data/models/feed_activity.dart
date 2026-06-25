/// A workspace activity event, from `GET /api/v1/activity` — the collaboration
/// history timeline. Carries the task title so it can be shown without a
/// second fetch. Manual JSON serialization per AGENTS.md §9.
class FeedActivity {
  final int id;
  final int taskId;
  final String taskTitle;
  final int? actorId;
  final String actorName;
  final String action;
  final String detail;
  final DateTime createdAt;

  const FeedActivity({
    required this.id,
    required this.taskId,
    required this.createdAt,
    this.taskTitle = '',
    this.actorId,
    this.actorName = '',
    this.action = '',
    this.detail = '',
  });

  factory FeedActivity.fromJson(Map<String, dynamic> json) => FeedActivity(
    id: json['id'] as int,
    taskId: json['task_id'] as int,
    taskTitle: json['task_title'] as String? ?? '',
    actorId: json['actor_id'] as int?,
    actorName: json['actor_name'] as String? ?? '',
    action: json['action'] as String? ?? '',
    detail: json['detail'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'task_id': taskId,
    'task_title': taskTitle,
    'actor_id': actorId,
    'actor_name': actorName,
    'action': action,
    'detail': detail,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'FeedActivity(id: $id, action: $action, task: $taskId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedActivity &&
          other.id == id &&
          other.taskId == taskId &&
          other.taskTitle == taskTitle &&
          other.actorId == actorId &&
          other.actorName == actorName &&
          other.action == action &&
          other.detail == detail &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    taskTitle,
    actorId,
    actorName,
    action,
    detail,
    createdAt,
  );
}
