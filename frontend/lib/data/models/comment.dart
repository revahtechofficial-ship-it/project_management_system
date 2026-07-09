/// A comment on a task, from `GET /api/v1/tasks/{id}/comments`. Manual JSON
/// serialization per AGENTS.md §9.
class Comment {
  final int id;
  final int taskId;
  final int? authorId;
  final String? authorName;
  final int? parentId;
  final String body;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.taskId,
    required this.createdAt,
    this.authorId,
    this.authorName,
    this.parentId,
    this.body = '',
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as int,
    taskId: json['task_id'] as int,
    authorId: json['author_id'] as int?,
    authorName: json['author_name'] as String?,
    parentId: json['parent_id'] as int?,
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'task_id': taskId,
    'author_id': authorId,
    'author_name': authorName,
    'parent_id': parentId,
    'body': body,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'Comment(id: $id, author: $authorName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment &&
          other.id == id &&
          other.taskId == taskId &&
          other.authorId == authorId &&
          other.authorName == authorName &&
          other.parentId == parentId &&
          other.body == body &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, taskId, authorId, authorName, parentId, body, createdAt);
}
