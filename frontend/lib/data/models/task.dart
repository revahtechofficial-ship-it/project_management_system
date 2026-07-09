import 'package:flutter/foundation.dart';

import '../enums/issue_type.dart';
import '../enums/recurrence_type.dart';
import '../enums/task_priority.dart';
import '../enums/task_severity.dart';
import '../enums/task_status.dart';

/// A task, mirroring the backend `tasks` table (plus the joined project and
/// assignee names from the list query).
///
/// Manual JSON serialization per AGENTS.md §9 (no `json_serializable`).
/// JSON keys are `snake_case` to match the API.
class Task {
  final int id;
  final String title;
  final String description;
  final bool done;
  final TaskStatus status;
  final String statusKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? projectId;
  final int? assigneeId;
  final String? projectName;
  final String? assigneeName;
  final DateTime? startDate;
  final DateTime? dueDate;
  final int? parentId;
  final RecurrenceType recurrence;
  final int subtaskCount;
  final int subtaskDoneCount;
  final DateTime? baselineStart;
  final DateTime? baselineDue;
  final TaskPriority priority;
  final List<String> tags;
  final int estimateMinutes;
  final int? sprintId;
  final int points;
  final IssueType issueType;
  final TaskSeverity severity;
  final int? releaseId;
  final List<int> assigneeIds;
  final List<String> assigneeNames;

  const Task({
    required this.id,
    required this.done,
    required this.createdAt,
    required this.updatedAt,
    this.status = TaskStatus.todo,
    this.statusKey = 'todo',
    this.title = '',
    this.description = '',
    this.projectId,
    this.assigneeId,
    this.projectName,
    this.assigneeName,
    this.startDate,
    this.dueDate,
    this.parentId,
    this.recurrence = RecurrenceType.none,
    this.subtaskCount = 0,
    this.subtaskDoneCount = 0,
    this.baselineStart,
    this.baselineDue,
    this.priority = TaskPriority.none,
    this.tags = const <String>[],
    this.estimateMinutes = 0,
    this.sprintId,
    this.points = 0,
    this.issueType = IssueType.task,
    this.severity = TaskSeverity.none,
    this.releaseId,
    this.assigneeIds = const <int>[],
    this.assigneeNames = const <String>[],
  });

  /// Returns a copy with the given fields replaced. Used for optimistic UI
  /// updates (e.g. flipping [done] before the server confirms).
  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool? done,
    TaskStatus? status,
    String? statusKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? projectId,
    int? assigneeId,
    String? projectName,
    String? assigneeName,
    DateTime? startDate,
    DateTime? dueDate,
    int? parentId,
    RecurrenceType? recurrence,
    int? subtaskCount,
    int? subtaskDoneCount,
    DateTime? baselineStart,
    DateTime? baselineDue,
    TaskPriority? priority,
    List<String>? tags,
    int? estimateMinutes,
    int? sprintId,
    int? points,
    IssueType? issueType,
    TaskSeverity? severity,
    int? releaseId,
    List<int>? assigneeIds,
    List<String>? assigneeNames,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    done: done ?? this.done,
    status: status ?? this.status,
    statusKey: statusKey ?? this.statusKey,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    projectId: projectId ?? this.projectId,
    assigneeId: assigneeId ?? this.assigneeId,
    projectName: projectName ?? this.projectName,
    assigneeName: assigneeName ?? this.assigneeName,
    startDate: startDate ?? this.startDate,
    dueDate: dueDate ?? this.dueDate,
    parentId: parentId ?? this.parentId,
    recurrence: recurrence ?? this.recurrence,
    subtaskCount: subtaskCount ?? this.subtaskCount,
    subtaskDoneCount: subtaskDoneCount ?? this.subtaskDoneCount,
    baselineStart: baselineStart ?? this.baselineStart,
    baselineDue: baselineDue ?? this.baselineDue,
    priority: priority ?? this.priority,
    tags: tags ?? this.tags,
    estimateMinutes: estimateMinutes ?? this.estimateMinutes,
    sprintId: sprintId ?? this.sprintId,
    points: points ?? this.points,
    issueType: issueType ?? this.issueType,
    severity: severity ?? this.severity,
    releaseId: releaseId ?? this.releaseId,
    assigneeIds: assigneeIds ?? this.assigneeIds,
    assigneeNames: assigneeNames ?? this.assigneeNames,
  );

  /// Compact assignee summary for cards, e.g. "Alice" or "Alice +2".
  String get assigneeLabel {
    if (assigneeNames.isEmpty) {
      return '';
    }
    if (assigneeNames.length == 1) {
      return assigneeNames.first;
    }
    return '${assigneeNames.first} +${assigneeNames.length - 1}';
  }

  /// Human-readable estimate (e.g. "2h 30m", "45m"), or '' when unset.
  String get estimateLabel {
    if (estimateMinutes <= 0) {
      return '';
    }
    final int h = estimateMinutes ~/ 60;
    final int m = estimateMinutes % 60;
    if (h > 0 && m > 0) {
      return '${h}h ${m}m';
    }
    return h > 0 ? '${h}h' : '${m}m';
  }

  /// Builds a [Task] from a decoded JSON map with snake_case keys.
  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    done: json['done'] as bool,
    status: TaskStatus.fromJson(json['status'] as String? ?? 'todo'),
    statusKey: json['status'] as String? ?? 'todo',
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    projectId: json['project_id'] as int?,
    assigneeId: json['assignee_id'] as int?,
    projectName: json['project_name'] as String?,
    assigneeName: json['assignee_name'] as String?,
    startDate: json['start_date'] == null
        ? null
        : DateTime.parse(json['start_date'] as String),
    dueDate: json['due_date'] == null
        ? null
        : DateTime.parse(json['due_date'] as String),
    parentId: json['parent_id'] as int?,
    recurrence: RecurrenceType.fromJson(
      json['recurrence'] as String? ?? 'none',
    ),
    subtaskCount: json['subtask_count'] as int? ?? 0,
    subtaskDoneCount: json['subtask_done_count'] as int? ?? 0,
    baselineStart: json['baseline_start'] == null
        ? null
        : DateTime.parse(json['baseline_start'] as String),
    baselineDue: json['baseline_due'] == null
        ? null
        : DateTime.parse(json['baseline_due'] as String),
    priority: TaskPriority.fromJson(json['priority'] as String? ?? 'none'),
    tags:
        (json['tags'] as List<dynamic>?)
            ?.map((dynamic e) => e as String)
            .toList(growable: false) ??
        const <String>[],
    estimateMinutes: json['estimate_minutes'] as int? ?? 0,
    sprintId: json['sprint_id'] as int?,
    points: json['points'] as int? ?? 0,
    issueType: IssueType.fromJson(json['issue_type'] as String? ?? 'task'),
    severity: TaskSeverity.fromJson(json['severity'] as String? ?? 'none'),
    releaseId: json['release_id'] as int?,
    assigneeIds:
        (json['assignee_ids'] as List<dynamic>?)
            ?.map((dynamic e) => (e as num).toInt())
            .toList(growable: false) ??
        const <int>[],
    assigneeNames:
        (json['assignee_names'] as List<dynamic>?)
            ?.map((dynamic e) => e as String)
            .toList(growable: false) ??
        const <String>[],
  );

  /// Serializes this task to a JSON map with snake_case keys.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'done': done,
    'status': statusKey,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'project_id': projectId,
    'assignee_id': assigneeId,
    'project_name': projectName,
    'assignee_name': assigneeName,
    'start_date': startDate?.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'parent_id': parentId,
    'recurrence': recurrence.toJson(),
    'subtask_count': subtaskCount,
    'subtask_done_count': subtaskDoneCount,
    'baseline_start': baselineStart?.toIso8601String(),
    'baseline_due': baselineDue?.toIso8601String(),
    'priority': priority.toJson(),
    'tags': tags,
    'estimate_minutes': estimateMinutes,
    'sprint_id': sprintId,
    'points': points,
    'issue_type': issueType.toJson(),
    'severity': severity.toJson(),
    'release_id': releaseId,
    'assignee_ids': assigneeIds,
    'assignee_names': assigneeNames,
  };

  @override
  String toString() =>
      'Task('
      'id: $id, '
      'title: $title, '
      'description: $description, '
      'done: $done, '
      'createdAt: $createdAt, '
      'updatedAt: $updatedAt, '
      'projectId: $projectId, '
      'assigneeId: $assigneeId'
      ')';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.done == done &&
          other.status == status &&
          other.statusKey == statusKey &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.projectId == projectId &&
          other.assigneeId == assigneeId &&
          other.projectName == projectName &&
          other.assigneeName == assigneeName &&
          other.startDate == startDate &&
          other.dueDate == dueDate &&
          other.parentId == parentId &&
          other.recurrence == recurrence &&
          other.subtaskCount == subtaskCount &&
          other.subtaskDoneCount == subtaskDoneCount &&
          other.baselineStart == baselineStart &&
          other.baselineDue == baselineDue &&
          other.priority == priority &&
          other.estimateMinutes == estimateMinutes &&
          other.sprintId == sprintId &&
          other.points == points &&
          other.issueType == issueType &&
          other.severity == severity &&
          other.releaseId == releaseId &&
          listEquals(other.assigneeIds, assigneeIds) &&
          listEquals(other.assigneeNames, assigneeNames) &&
          listEquals(other.tags, tags);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    title,
    description,
    done,
    status,
    statusKey,
    createdAt,
    updatedAt,
    projectId,
    assigneeId,
    projectName,
    assigneeName,
    startDate,
    dueDate,
    parentId,
    recurrence,
    subtaskCount,
    subtaskDoneCount,
    baselineStart,
    baselineDue,
    priority,
    estimateMinutes,
    sprintId,
    points,
    issueType,
    severity,
    releaseId,
    Object.hashAll(assigneeIds),
    Object.hashAll(assigneeNames),
    Object.hashAll(tags),
  ]);
}
