import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// How urgent a bug or incident is. Tied to the model, so it carries
/// `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum IncidentSeverity {
  critical,
  high,
  medium,
  low;

  String get label => switch (this) {
    IncidentSeverity.critical => 'Critical',
    IncidentSeverity.high => 'High',
    IncidentSeverity.medium => 'Medium',
    IncidentSeverity.low => 'Low',
  };

  Color get color => switch (this) {
    IncidentSeverity.critical => AppColors.rose,
    IncidentSeverity.high => AppColors.orange,
    IncidentSeverity.medium => AppColors.amber,
    IncidentSeverity.low => AppColors.slate,
  };

  String toJson() => switch (this) {
    IncidentSeverity.critical => 'critical',
    IncidentSeverity.high => 'high',
    IncidentSeverity.medium => 'medium',
    IncidentSeverity.low => 'low',
  };

  factory IncidentSeverity.fromJson(String value) => switch (value) {
    'critical' => IncidentSeverity.critical,
    'high' => IncidentSeverity.high,
    'low' => IncidentSeverity.low,
    _ => IncidentSeverity.medium,
  };
}
