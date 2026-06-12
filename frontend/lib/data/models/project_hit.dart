/// A lightweight project result returned by global search
/// (`GET /api/v1/search`). Manual JSON serialization per AGENTS.md §9.
class ProjectHit {
  final int id;
  final String name;
  final String status;
  final DateTime? dueDate;

  const ProjectHit({
    required this.id,
    this.name = '',
    this.status = '',
    this.dueDate,
  });

  factory ProjectHit.fromJson(Map<String, dynamic> json) => ProjectHit(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        status: json['status'] as String? ?? '',
        dueDate: json['due_date'] == null
            ? null
            : DateTime.parse(json['due_date'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'status': status,
        'due_date': dueDate?.toIso8601String(),
      };

  @override
  String toString() => 'ProjectHit(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectHit &&
          other.id == id &&
          other.name == name &&
          other.status == status &&
          other.dueDate == dueDate;

  @override
  int get hashCode => Object.hash(id, name, status, dueDate);
}
