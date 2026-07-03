import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A column of a sprint retrospective. Tied to the `RetroItem` model, so it
/// carries `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum RetroKind {
  start,
  stop,
  keepGoing,
  action;

  String get label => switch (this) {
        RetroKind.start => 'Start',
        RetroKind.stop => 'Stop',
        RetroKind.keepGoing => 'Continue',
        RetroKind.action => 'Action items',
      };

  Color get color => switch (this) {
        RetroKind.start => AppColors.green,
        RetroKind.stop => AppColors.rose,
        RetroKind.keepGoing => AppColors.brand,
        RetroKind.action => AppColors.amber,
      };

  IconData get icon => switch (this) {
        RetroKind.start => Icons.play_arrow_rounded,
        RetroKind.stop => Icons.stop_rounded,
        RetroKind.keepGoing => Icons.trending_up_rounded,
        RetroKind.action => Icons.task_alt_rounded,
      };

  String toJson() => switch (this) {
        RetroKind.start => 'start',
        RetroKind.stop => 'stop',
        RetroKind.keepGoing => 'continue',
        RetroKind.action => 'action',
      };

  factory RetroKind.fromJson(String value) => switch (value) {
        'stop' => RetroKind.stop,
        'continue' => RetroKind.keepGoing,
        'action' => RetroKind.action,
        _ => RetroKind.start,
      };
}
