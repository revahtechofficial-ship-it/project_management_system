import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Triage lifecycle of a bug or incident. Tied to the model, so it carries
/// `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum IncidentStatus {
  open,
  investigating,
  mitigated,
  resolved,
  closed;

  String get label => switch (this) {
        IncidentStatus.open => 'Open',
        IncidentStatus.investigating => 'Investigating',
        IncidentStatus.mitigated => 'Mitigated',
        IncidentStatus.resolved => 'Resolved',
        IncidentStatus.closed => 'Closed',
      };

  Color get color => switch (this) {
        IncidentStatus.open => AppColors.rose,
        IncidentStatus.investigating => AppColors.amber,
        IncidentStatus.mitigated => AppColors.sky,
        IncidentStatus.resolved => AppColors.green,
        IncidentStatus.closed => AppColors.slate,
      };

  /// True while the issue still needs attention (not resolved or closed).
  bool get isActive => switch (this) {
        IncidentStatus.open ||
        IncidentStatus.investigating ||
        IncidentStatus.mitigated =>
          true,
        IncidentStatus.resolved || IncidentStatus.closed => false,
      };

  String toJson() => switch (this) {
        IncidentStatus.open => 'open',
        IncidentStatus.investigating => 'investigating',
        IncidentStatus.mitigated => 'mitigated',
        IncidentStatus.resolved => 'resolved',
        IncidentStatus.closed => 'closed',
      };

  factory IncidentStatus.fromJson(String value) => switch (value) {
        'investigating' => IncidentStatus.investigating,
        'mitigated' => IncidentStatus.mitigated,
        'resolved' => IncidentStatus.resolved,
        'closed' => IncidentStatus.closed,
        _ => IncidentStatus.open,
      };
}
