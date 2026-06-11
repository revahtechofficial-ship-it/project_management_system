import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A task's workflow status. Tied to the `Task` model, so it carries
/// `toJson` / `fromJson` with a sentinel default (AGENTS.md §9 Enums).
enum TaskStatus {
  backlog,
  todo,
  inProgress,
  review,
  done,
  other;

  String get label => switch (this) {
        TaskStatus.backlog => 'Backlog',
        TaskStatus.todo => 'To Do',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.review => 'Review',
        TaskStatus.done => 'Done',
        TaskStatus.other => 'Unknown',
      };

  Color get color => switch (this) {
        TaskStatus.backlog => AppColors.slate,
        TaskStatus.todo => AppColors.sky,
        TaskStatus.inProgress => AppColors.brand,
        TaskStatus.review => AppColors.violet,
        TaskStatus.done => AppColors.green,
        TaskStatus.other => AppColors.slate,
      };

  String toJson() => switch (this) {
        TaskStatus.backlog => 'backlog',
        TaskStatus.todo => 'todo',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.review => 'review',
        TaskStatus.done => 'done',
        TaskStatus.other => '',
      };

  factory TaskStatus.fromJson(String value) => switch (value) {
        'backlog' => TaskStatus.backlog,
        'todo' => TaskStatus.todo,
        'in_progress' => TaskStatus.inProgress,
        'review' => TaskStatus.review,
        'done' => TaskStatus.done,
        _ => TaskStatus.todo,
      };

  /// The columns of the Kanban board, in order.
  static List<TaskStatus> get board => <TaskStatus>[
        TaskStatus.backlog,
        TaskStatus.todo,
        TaskStatus.inProgress,
        TaskStatus.review,
        TaskStatus.done,
      ];
}
