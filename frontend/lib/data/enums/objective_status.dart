import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The lifecycle status of an objective. Tied to the [Objective] model, so it
/// carries `toJson`/`fromJson` with a sentinel default (AGENTS.md §9).
enum ObjectiveStatus {
  active,
  completed,
  archived,
  unknown;

  String get label => switch (this) {
    ObjectiveStatus.active => 'Active',
    ObjectiveStatus.completed => 'Completed',
    ObjectiveStatus.archived => 'Archived',
    ObjectiveStatus.unknown => 'Active',
  };

  Color get color => switch (this) {
    ObjectiveStatus.active => AppColors.brand,
    ObjectiveStatus.completed => AppColors.green,
    ObjectiveStatus.archived => AppColors.slate,
    ObjectiveStatus.unknown => AppColors.brand,
  };

  String toJson() => switch (this) {
    ObjectiveStatus.active => 'active',
    ObjectiveStatus.completed => 'completed',
    ObjectiveStatus.archived => 'archived',
    ObjectiveStatus.unknown => '',
  };

  factory ObjectiveStatus.fromJson(String value) => switch (value) {
    'active' => ObjectiveStatus.active,
    'completed' => ObjectiveStatus.completed,
    'archived' => ObjectiveStatus.archived,
    _ => ObjectiveStatus.unknown,
  };

  /// The statuses offered in the form (excludes the sentinel).
  static List<ObjectiveStatus> get selectable => <ObjectiveStatus>[
    ObjectiveStatus.active,
    ObjectiveStatus.completed,
    ObjectiveStatus.archived,
  ];
}
