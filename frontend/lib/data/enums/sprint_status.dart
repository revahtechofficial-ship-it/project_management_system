import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Lifecycle state of a sprint. Tied to the `Sprint` model (AGENTS.md §9).
enum SprintStatus {
  planned,
  active,
  completed,
  other;

  String get label => switch (this) {
    SprintStatus.planned => 'Planned',
    SprintStatus.active => 'Active',
    SprintStatus.completed => 'Completed',
    SprintStatus.other => 'Unknown',
  };

  Color get color => switch (this) {
    SprintStatus.planned => AppColors.slate,
    SprintStatus.active => AppColors.brand,
    SprintStatus.completed => AppColors.green,
    SprintStatus.other => AppColors.slate,
  };

  String toJson() => switch (this) {
    SprintStatus.planned => 'planned',
    SprintStatus.active => 'active',
    SprintStatus.completed => 'completed',
    SprintStatus.other => '',
  };

  factory SprintStatus.fromJson(String value) => switch (value) {
    'planned' => SprintStatus.planned,
    'active' => SprintStatus.active,
    'completed' => SprintStatus.completed,
    _ => SprintStatus.other,
  };
}
