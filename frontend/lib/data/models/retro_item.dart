import '../enums/retro_kind.dart';

/// One card on a sprint retrospective board (Start/Stop/Continue) or an action
/// item, from `/api/v1/sprints/{id}/retro`. Manual JSON per AGENTS.md §9.
class RetroItem {
  final int id;
  final int sprintId;
  final RetroKind kind;
  final String body;
  final String authorName;
  final bool done;
  final DateTime createdAt;

  const RetroItem({
    required this.id,
    required this.sprintId,
    required this.createdAt,
    this.kind = RetroKind.start,
    this.body = '',
    this.authorName = '',
    this.done = false,
  });

  factory RetroItem.fromJson(Map<String, dynamic> json) => RetroItem(
        id: json['id'] as int,
        sprintId: json['sprint_id'] as int,
        kind: RetroKind.fromJson(json['kind'] as String? ?? 'start'),
        body: json['body'] as String? ?? '',
        authorName: json['author_name'] as String? ?? '',
        done: json['done'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sprint_id': sprintId,
        'kind': kind.toJson(),
        'body': body,
        'author_name': authorName,
        'done': done,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'RetroItem(id: $id, ${kind.name}: $body)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetroItem &&
          other.id == id &&
          other.sprintId == sprintId &&
          other.kind == kind &&
          other.body == body &&
          other.authorName == authorName &&
          other.done == done &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, sprintId, kind, body, authorName, done, createdAt);
}
