import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// What a dot on the Patro calendar stands for. A pure UI enum — it is derived
/// from other models rather than sent over the wire, so it carries no
/// `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum CalendarEventKind {
  holiday,
  personal,
  task,
  leave;

  String get label => switch (this) {
    CalendarEventKind.holiday => 'Holiday',
    CalendarEventKind.personal => 'My events',
    CalendarEventKind.task => 'Task due',
    CalendarEventKind.leave => 'Leave',
  };

  /// The Nepali label, for when the calendar renders in Nepali.
  String get labelNe => switch (this) {
    CalendarEventKind.holiday => 'बिदा',
    CalendarEventKind.personal => 'मेरो',
    CalendarEventKind.task => 'काम',
    CalendarEventKind.leave => 'छुट्टी',
  };

  Color get color => switch (this) {
    CalendarEventKind.holiday => AppColors.rose,
    CalendarEventKind.personal => AppColors.violet,
    CalendarEventKind.task => AppColors.brand,
    CalendarEventKind.leave => AppColors.teal,
  };

  IconData get icon => switch (this) {
    CalendarEventKind.holiday => Icons.celebration_outlined,
    CalendarEventKind.personal => Icons.push_pin_outlined,
    CalendarEventKind.task => Icons.check_circle_outline,
    CalendarEventKind.leave => Icons.beach_access_outlined,
  };
}
