import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The kind of work item a task represents. Tied to the `Task` model, so it
/// carries `toJson` / `fromJson` with a sentinel default (AGENTS.md §9 Enums).
enum IssueType {
  task,
  bug,
  story,
  epic;

  String get label => switch (this) {
    IssueType.task => 'Task',
    IssueType.bug => 'Bug',
    IssueType.story => 'Story',
    IssueType.epic => 'Epic',
  };

  IconData get icon => switch (this) {
    IssueType.task => Icons.check_box_outlined,
    IssueType.bug => Icons.bug_report_outlined,
    IssueType.story => Icons.bookmark_outline,
    IssueType.epic => Icons.bolt_outlined,
  };

  Color get color => switch (this) {
    IssueType.task => AppColors.sky,
    IssueType.bug => AppColors.rose,
    IssueType.story => AppColors.green,
    IssueType.epic => AppColors.violet,
  };

  String toJson() => switch (this) {
    IssueType.task => 'task',
    IssueType.bug => 'bug',
    IssueType.story => 'story',
    IssueType.epic => 'epic',
  };

  factory IssueType.fromJson(String value) => switch (value) {
    'bug' => IssueType.bug,
    'story' => IssueType.story,
    'epic' => IssueType.epic,
    _ => IssueType.task,
  };
}
