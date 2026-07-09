import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The kind of time off in a leave request. Tied to the `LeaveRequest` model,
/// so it carries `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum LeaveType {
  vacation,
  sick,
  personal,
  other;

  String get label => switch (this) {
    LeaveType.vacation => 'Vacation',
    LeaveType.sick => 'Sick',
    LeaveType.personal => 'Personal',
    LeaveType.other => 'Other',
  };

  Color get color => switch (this) {
    LeaveType.vacation => AppColors.sky,
    LeaveType.sick => AppColors.rose,
    LeaveType.personal => AppColors.violet,
    LeaveType.other => AppColors.slate,
  };

  IconData get icon => switch (this) {
    LeaveType.vacation => Icons.beach_access_outlined,
    LeaveType.sick => Icons.sick_outlined,
    LeaveType.personal => Icons.person_outline,
    LeaveType.other => Icons.event_busy_outlined,
  };

  String toJson() => name;

  factory LeaveType.fromJson(String value) => switch (value) {
    'vacation' => LeaveType.vacation,
    'sick' => LeaveType.sick,
    'personal' => LeaveType.personal,
    _ => LeaveType.other,
  };
}
