import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Whether a tracked issue is a code [bug] or an operational [incident]. Tied
/// to the model, so it carries `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum IncidentKind {
  bug,
  incident;

  String get label => switch (this) {
        IncidentKind.bug => 'Bug',
        IncidentKind.incident => 'Incident',
      };

  Color get color => switch (this) {
        IncidentKind.bug => AppColors.violet,
        IncidentKind.incident => AppColors.orange,
      };

  IconData get icon => switch (this) {
        IncidentKind.bug => Icons.bug_report_outlined,
        IncidentKind.incident => Icons.crisis_alert_outlined,
      };

  String toJson() => switch (this) {
        IncidentKind.bug => 'bug',
        IncidentKind.incident => 'incident',
      };

  factory IncidentKind.fromJson(String value) => switch (value) {
        'incident' => IncidentKind.incident,
        _ => IncidentKind.bug,
      };
}
