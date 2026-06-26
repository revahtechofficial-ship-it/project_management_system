import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A release's lifecycle stage. Tied to the `Release` model, so it carries
/// `toJson` / `fromJson` with a sentinel default (AGENTS.md §9 Enums).
enum ReleaseStatus {
  planned,
  inProgress,
  released;

  String get label => switch (this) {
    ReleaseStatus.planned => 'Planned',
    ReleaseStatus.inProgress => 'In progress',
    ReleaseStatus.released => 'Released',
  };

  Color get color => switch (this) {
    ReleaseStatus.planned => AppColors.slate,
    ReleaseStatus.inProgress => AppColors.sky,
    ReleaseStatus.released => AppColors.green,
  };

  String toJson() => switch (this) {
    ReleaseStatus.planned => 'planned',
    ReleaseStatus.inProgress => 'in_progress',
    ReleaseStatus.released => 'released',
  };

  factory ReleaseStatus.fromJson(String value) => switch (value) {
    'in_progress' => ReleaseStatus.inProgress,
    'released' => ReleaseStatus.released,
    _ => ReleaseStatus.planned,
  };
}
