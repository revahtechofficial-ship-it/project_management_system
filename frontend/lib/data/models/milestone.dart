/// A project milestone — a named, dated checkpoint, from
/// `GET /api/v1/milestones`. Manual JSON serialization (AGENTS.md §9).
class Milestone {
  final int id;
  final int? projectId;
  final String name;
  final DateTime dueDate;
  final bool done;

  const Milestone({
    required this.id,
    required this.dueDate,
    required this.done,
    this.projectId,
    this.name = '',
  });

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
    id: json['id'] as int,
    projectId: json['project_id'] as int?,
    name: json['name'] as String? ?? '',
    dueDate: DateTime.parse(json['due_date'] as String),
    done: json['done'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'project_id': projectId,
    'name': name,
    'due_date': dueDate.toIso8601String(),
    'done': done,
  };

  @override
  String toString() =>
      'Milestone(id: $id, name: $name, dueDate: $dueDate, done: $done)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Milestone &&
          other.id == id &&
          other.projectId == projectId &&
          other.name == name &&
          other.dueDate == dueDate &&
          other.done == done;

  @override
  int get hashCode => Object.hash(id, projectId, name, dueDate, done);
}
