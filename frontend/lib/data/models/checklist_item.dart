/// A lightweight checklist item belonging to a task, from
/// `GET /api/v1/tasks/{id}/checklist`. Manual JSON serialization (AGENTS.md §9).
class ChecklistItem {
  final int id;
  final int taskId;
  final String content;
  final bool done;
  final int position;

  const ChecklistItem({
    required this.id,
    required this.taskId,
    required this.done,
    this.content = '',
    this.position = 0,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as int,
        taskId: json['task_id'] as int,
        content: json['content'] as String? ?? '',
        done: json['done'] as bool? ?? false,
        position: json['position'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'task_id': taskId,
        'content': content,
        'done': done,
        'position': position,
      };

  @override
  String toString() =>
      'ChecklistItem(id: $id, content: $content, done: $done)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistItem &&
          other.id == id &&
          other.taskId == taskId &&
          other.content == content &&
          other.done == done &&
          other.position == position;

  @override
  int get hashCode => Object.hash(id, taskId, content, done, position);
}
