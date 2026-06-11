import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Delivery status of a project. Tied to the `Project` model (AGENTS.md §9).
enum ProjectStatus {
  planning,
  active,
  onHold,
  completed,
  other;

  String get label => switch (this) {
        ProjectStatus.planning => 'Planning',
        ProjectStatus.active => 'Active',
        ProjectStatus.onHold => 'On Hold',
        ProjectStatus.completed => 'Completed',
        ProjectStatus.other => 'Unknown',
      };

  Color get color => switch (this) {
        ProjectStatus.planning => AppColors.sky,
        ProjectStatus.active => AppColors.brand,
        ProjectStatus.onHold => AppColors.amber,
        ProjectStatus.completed => AppColors.green,
        ProjectStatus.other => AppColors.slate,
      };

  String toJson() => switch (this) {
        ProjectStatus.planning => 'planning',
        ProjectStatus.active => 'active',
        ProjectStatus.onHold => 'on_hold',
        ProjectStatus.completed => 'completed',
        ProjectStatus.other => '',
      };

  factory ProjectStatus.fromJson(String value) => switch (value) {
        'planning' => ProjectStatus.planning,
        'active' => ProjectStatus.active,
        'on_hold' => ProjectStatus.onHold,
        'completed' => ProjectStatus.completed,
        _ => ProjectStatus.other,
      };
}
