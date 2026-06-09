/// A task, mirroring the backend `tasks` table.
///
/// Manual JSON serialization per AGENTS.md §9 (no `json_serializable`).
/// JSON keys are `snake_case` to match the API.
class Task {
  final int id;
  final String title;
  final String description;
  final bool done;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.done,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.description = '',
  });

  /// Builds a [Task] from a decoded JSON map with snake_case keys.
  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        done: json['done'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// Serializes this task to a JSON map with snake_case keys.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'done': done,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  String toString() => 'Task('
      'id: $id, '
      'title: $title, '
      'description: $description, '
      'done: $done, '
      'createdAt: $createdAt, '
      'updatedAt: $updatedAt'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.done == done &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        done,
        createdAt,
        updatedAt,
      );
}
