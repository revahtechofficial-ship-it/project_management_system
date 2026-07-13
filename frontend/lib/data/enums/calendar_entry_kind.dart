import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// What kind of personal calendar entry this is. Tied to the `CalendarEntry`
/// model, so it carries `toJson` / `fromJson` with [note] as the resilient
/// default (AGENTS.md §9 Enums).
enum CalendarEntryKind {
  note,
  birthday,
  anniversary,
  meeting,
  custom;

  String get label => switch (this) {
    CalendarEntryKind.note => 'Note',
    CalendarEntryKind.birthday => 'Birthday',
    CalendarEntryKind.anniversary => 'Anniversary',
    CalendarEntryKind.meeting => 'Meeting',
    CalendarEntryKind.custom => 'Custom',
  };

  String get labelNe => switch (this) {
    CalendarEntryKind.note => 'नोट',
    CalendarEntryKind.birthday => 'जन्मदिन',
    CalendarEntryKind.anniversary => 'वार्षिकोत्सव',
    CalendarEntryKind.meeting => 'बैठक',
    CalendarEntryKind.custom => 'अन्य',
  };

  Color get color => switch (this) {
    CalendarEntryKind.note => AppColors.slate,
    CalendarEntryKind.birthday => AppColors.rose,
    CalendarEntryKind.anniversary => AppColors.violet,
    CalendarEntryKind.meeting => AppColors.sky,
    CalendarEntryKind.custom => AppColors.amber,
  };

  IconData get icon => switch (this) {
    CalendarEntryKind.note => Icons.sticky_note_2_outlined,
    CalendarEntryKind.birthday => Icons.cake_outlined,
    CalendarEntryKind.anniversary => Icons.favorite_outline,
    CalendarEntryKind.meeting => Icons.groups_outlined,
    CalendarEntryKind.custom => Icons.push_pin_outlined,
  };

  /// A birthday or an anniversary is meant to come round again; a note is not.
  bool get repeatsByDefault =>
      this == CalendarEntryKind.birthday ||
      this == CalendarEntryKind.anniversary;

  String toJson() => name;

  factory CalendarEntryKind.fromJson(String value) => switch (value) {
    'birthday' => CalendarEntryKind.birthday,
    'anniversary' => CalendarEntryKind.anniversary,
    'meeting' => CalendarEntryKind.meeting,
    'custom' => CalendarEntryKind.custom,
    _ => CalendarEntryKind.note,
  };
}

/// Which calendar a yearly event repeats in.
///
/// This is not a detail. A birthday kept on 15 Ashar falls on a different
/// Gregorian day every year; a birthday kept on 9 July falls on a different
/// Bikram Sambat day every year. The event has to say which it means, or it
/// will be shown on the wrong day for everyone who keeps theirs the other way.
enum RepeatIn {
  none,
  ad,
  bs;

  String get label => switch (this) {
    RepeatIn.none => 'Does not repeat',
    RepeatIn.ad => 'Yearly, by English date',
    RepeatIn.bs => 'Yearly, by Nepali date',
  };

  String get labelNe => switch (this) {
    RepeatIn.none => 'दोहोरिँदैन',
    RepeatIn.ad => 'हरेक वर्ष, अंग्रेजी मितिमा',
    RepeatIn.bs => 'हरेक वर्ष, नेपाली मितिमा',
  };

  /// A one-line reminder of what the choice actually means.
  String get hint => switch (this) {
    RepeatIn.none => 'A single day.',
    RepeatIn.ad => 'The same Gregorian day each year — 9 July, always.',
    RepeatIn.bs =>
      'The same BS day each year — 25 Ashar, whatever Gregorian '
          'day that lands on.',
  };

  bool get repeats => this != RepeatIn.none;

  String toJson() => name;

  factory RepeatIn.fromJson(String value) => switch (value) {
    'ad' => RepeatIn.ad,
    'bs' => RepeatIn.bs,
    _ => RepeatIn.none,
  };
}
