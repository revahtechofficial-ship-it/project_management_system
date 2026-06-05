import 'package:json_annotation/json_annotation.dart';

part 'task.g.dart';

/// A task, mirroring the backend `tasks` table. JSON keys are camelCase to
/// match the Go API (sqlc is configured with camelCase JSON tags).
@JsonSerializable()
class Task {
  final int id;
  final String title;
  final String description;
  final bool done;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.done,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);
}
