import 'package:flutter/foundation.dart';

import '../enums/recurrence_type.dart';
import '../enums/task_priority.dart';

/// A reusable task blueprint, from `GET /api/v1/task-templates`. The New-task
/// form is pre-filled from one. Manual JSON serialization per AGENTS.md §9.
class TaskTemplate {
  final int id;
  final String name;
  final String title;
  final String description;
  final String statusKey;
  final TaskPriority priority;
  final RecurrenceType recurrence;
  final int estimateMinutes;
  final List<String> tags;
  final int? projectId;

  const TaskTemplate({
    required this.id,
    this.name = '',
    this.title = '',
    this.description = '',
    this.statusKey = 'todo',
    this.priority = TaskPriority.none,
    this.recurrence = RecurrenceType.none,
    this.estimateMinutes = 0,
    this.tags = const <String>[],
    this.projectId,
  });

  factory TaskTemplate.fromJson(Map<String, dynamic> json) => TaskTemplate(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    statusKey: json['status'] as String? ?? 'todo',
    priority: TaskPriority.fromJson(json['priority'] as String? ?? 'none'),
    recurrence: RecurrenceType.fromJson(
      json['recurrence'] as String? ?? 'none',
    ),
    estimateMinutes: json['estimate_minutes'] as int? ?? 0,
    tags:
        (json['tags'] as List<dynamic>?)
            ?.map((dynamic e) => e as String)
            .toList(growable: false) ??
        const <String>[],
    projectId: json['project_id'] as int?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'title': title,
    'description': description,
    'status': statusKey,
    'priority': priority.toJson(),
    'recurrence': recurrence.toJson(),
    'estimate_minutes': estimateMinutes,
    'tags': tags,
    'project_id': projectId,
  };

  @override
  String toString() => 'TaskTemplate(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskTemplate &&
          other.id == id &&
          other.name == name &&
          other.title == title &&
          other.description == description &&
          other.statusKey == statusKey &&
          other.priority == priority &&
          other.recurrence == recurrence &&
          other.estimateMinutes == estimateMinutes &&
          other.projectId == projectId &&
          listEquals(other.tags, tags);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    title,
    description,
    statusKey,
    priority,
    recurrence,
    estimateMinutes,
    projectId,
    Object.hashAll(tags),
  );
}
