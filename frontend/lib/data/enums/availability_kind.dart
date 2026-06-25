import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Why a team member is unavailable for a stretch of days. Tied to the
/// [AvailabilityEntry] model, so it carries `toJson` / `fromJson` with a
/// sentinel default (AGENTS.md §9 Enums).
enum AvailabilityKind {
  vacation,
  sick,
  holiday,
  other;

  String get label => switch (this) {
    AvailabilityKind.vacation => 'Vacation',
    AvailabilityKind.sick => 'Sick leave',
    AvailabilityKind.holiday => 'Holiday',
    AvailabilityKind.other => 'Time off',
  };

  IconData get icon => switch (this) {
    AvailabilityKind.vacation => Icons.beach_access_outlined,
    AvailabilityKind.sick => Icons.healing_outlined,
    AvailabilityKind.holiday => Icons.celebration_outlined,
    AvailabilityKind.other => Icons.event_busy_outlined,
  };

  Color get color => switch (this) {
    AvailabilityKind.vacation => AppColors.sky,
    AvailabilityKind.sick => AppColors.rose,
    AvailabilityKind.holiday => AppColors.violet,
    AvailabilityKind.other => AppColors.slate,
  };

  String toJson() => switch (this) {
    AvailabilityKind.vacation => 'vacation',
    AvailabilityKind.sick => 'sick',
    AvailabilityKind.holiday => 'holiday',
    AvailabilityKind.other => 'other',
  };

  factory AvailabilityKind.fromJson(String value) => switch (value) {
    'vacation' => AvailabilityKind.vacation,
    'sick' => AvailabilityKind.sick,
    'holiday' => AvailabilityKind.holiday,
    _ => AvailabilityKind.other,
  };

  /// The kinds offered in the time-off dialog.
  static List<AvailabilityKind> get selectable => AvailabilityKind.values;
}
