import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The severity of a bug. Tied to the `Task` model, so it carries
/// `toJson` / `fromJson` with a sentinel default (AGENTS.md §9 Enums).
enum TaskSeverity {
  none,
  minor,
  major,
  critical;

  String get label => switch (this) {
    TaskSeverity.none => 'None',
    TaskSeverity.minor => 'Minor',
    TaskSeverity.major => 'Major',
    TaskSeverity.critical => 'Critical',
  };

  Color get color => switch (this) {
    TaskSeverity.none => AppColors.slate,
    TaskSeverity.minor => AppColors.teal,
    TaskSeverity.major => AppColors.orange,
    TaskSeverity.critical => AppColors.rose,
  };

  bool get isSet => this != TaskSeverity.none;

  String toJson() => switch (this) {
    TaskSeverity.none => 'none',
    TaskSeverity.minor => 'minor',
    TaskSeverity.major => 'major',
    TaskSeverity.critical => 'critical',
  };

  factory TaskSeverity.fromJson(String value) => switch (value) {
    'minor' => TaskSeverity.minor,
    'major' => TaskSeverity.major,
    'critical' => TaskSeverity.critical,
    _ => TaskSeverity.none,
  };
}
