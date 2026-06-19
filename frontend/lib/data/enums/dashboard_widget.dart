import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The catalogue of widgets a saved dashboard can show. UI/config enum — its
/// `key` (the enum name) is what gets stored in a dashboard's widget list
/// (AGENTS.md §9 filtering-style enum).
enum DashboardWidgetKind {
  totalTasks,
  completed,
  inProgress,
  overdue,
  completionRate,
  storyPoints,
  teamSize,
  projectCount,
  taskStatus,
  teamWorkload;

  String get key => name;

  String get label => switch (this) {
    DashboardWidgetKind.totalTasks => 'Total tasks',
    DashboardWidgetKind.completed => 'Completed',
    DashboardWidgetKind.inProgress => 'In progress',
    DashboardWidgetKind.overdue => 'Overdue',
    DashboardWidgetKind.completionRate => 'Completion rate',
    DashboardWidgetKind.storyPoints => 'Story points',
    DashboardWidgetKind.teamSize => 'Team size',
    DashboardWidgetKind.projectCount => 'Projects',
    DashboardWidgetKind.taskStatus => 'Task status chart',
    DashboardWidgetKind.teamWorkload => 'Team workload',
  };

  IconData get icon => switch (this) {
    DashboardWidgetKind.totalTasks => Icons.checklist_rounded,
    DashboardWidgetKind.completed => Icons.check_circle_outline,
    DashboardWidgetKind.inProgress => Icons.timelapse_outlined,
    DashboardWidgetKind.overdue => Icons.warning_amber_rounded,
    DashboardWidgetKind.completionRate => Icons.donut_large_outlined,
    DashboardWidgetKind.storyPoints => Icons.bolt_outlined,
    DashboardWidgetKind.teamSize => Icons.groups_2_outlined,
    DashboardWidgetKind.projectCount => Icons.folder_outlined,
    DashboardWidgetKind.taskStatus => Icons.pie_chart_outline,
    DashboardWidgetKind.teamWorkload => Icons.equalizer_rounded,
  };

  Color get color => switch (this) {
    DashboardWidgetKind.totalTasks => AppColors.brand,
    DashboardWidgetKind.completed => AppColors.green,
    DashboardWidgetKind.inProgress => AppColors.amber,
    DashboardWidgetKind.overdue => AppColors.rose,
    DashboardWidgetKind.completionRate => AppColors.sky,
    DashboardWidgetKind.storyPoints => AppColors.violet,
    DashboardWidgetKind.teamSize => AppColors.teal,
    DashboardWidgetKind.projectCount => AppColors.brand,
    DashboardWidgetKind.taskStatus => AppColors.sky,
    DashboardWidgetKind.teamWorkload => AppColors.violet,
  };

  /// Whether this widget spans the full width (charts) vs. a metric tile.
  bool get isWide =>
      this == DashboardWidgetKind.taskStatus ||
      this == DashboardWidgetKind.teamWorkload;

  /// Resolves a stored key to its widget kind, or null if unknown.
  static DashboardWidgetKind? byKey(String value) {
    for (final DashboardWidgetKind k in values) {
      if (k.name == value) {
        return k;
      }
    }
    return null;
  }
}
