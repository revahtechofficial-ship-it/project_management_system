import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A task's priority. Tied to the `Task` model, so it carries `toJson` /
/// `fromJson` with a sentinel default (AGENTS.md §9 Enums).
enum TaskPriority {
  none,
  low,
  normal,
  high,
  urgent;

  String get label => switch (this) {
        TaskPriority.none => 'No priority',
        TaskPriority.low => 'Low',
        TaskPriority.normal => 'Normal',
        TaskPriority.high => 'High',
        TaskPriority.urgent => 'Urgent',
      };

  Color get color => switch (this) {
        TaskPriority.none => AppColors.slate,
        TaskPriority.low => AppColors.teal,
        TaskPriority.normal => AppColors.sky,
        TaskPriority.high => AppColors.orange,
        TaskPriority.urgent => AppColors.rose,
      };

  /// Higher means more urgent — useful for sorting.
  int get rank => switch (this) {
        TaskPriority.none => 0,
        TaskPriority.low => 1,
        TaskPriority.normal => 2,
        TaskPriority.high => 3,
        TaskPriority.urgent => 4,
      };

  bool get isSet => this != TaskPriority.none;

  String toJson() => switch (this) {
        TaskPriority.none => 'none',
        TaskPriority.low => 'low',
        TaskPriority.normal => 'normal',
        TaskPriority.high => 'high',
        TaskPriority.urgent => 'urgent',
      };

  factory TaskPriority.fromJson(String value) => switch (value) {
        'low' => TaskPriority.low,
        'normal' => TaskPriority.normal,
        'high' => TaskPriority.high,
        'urgent' => TaskPriority.urgent,
        _ => TaskPriority.none,
      };
}
