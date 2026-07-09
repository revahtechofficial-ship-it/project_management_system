import '../enums/dependency_type.dart';

/// A precedence link between two tasks, from `GET /api/v1/dependencies`.
/// Manual JSON serialization per AGENTS.md §9.
class TaskDependency {
  final int id;
  final int predecessorId;
  final int successorId;
  final DependencyType type;

  const TaskDependency({
    required this.id,
    required this.predecessorId,
    required this.successorId,
    this.type = DependencyType.finishToStart,
  });

  factory TaskDependency.fromJson(Map<String, dynamic> json) => TaskDependency(
    id: json['id'] as int,
    predecessorId: json['predecessor_id'] as int,
    successorId: json['successor_id'] as int,
    type: DependencyType.fromJson(json['type'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'predecessor_id': predecessorId,
    'successor_id': successorId,
    'type': type.toJson(),
  };

  @override
  String toString() =>
      'TaskDependency('
      'id: $id, predecessorId: $predecessorId, '
      'successorId: $successorId, type: $type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskDependency &&
          other.id == id &&
          other.predecessorId == predecessorId &&
          other.successorId == successorId &&
          other.type == type;

  @override
  int get hashCode => Object.hash(id, predecessorId, successorId, type);
}
