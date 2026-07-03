import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The spend category of an [Expense]. Tied to the model, so it carries
/// `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum ExpenseCategory {
  travel,
  meals,
  software,
  hardware,
  office,
  subscriptions,
  other;

  String get label => switch (this) {
        ExpenseCategory.travel => 'Travel',
        ExpenseCategory.meals => 'Meals',
        ExpenseCategory.software => 'Software',
        ExpenseCategory.hardware => 'Hardware',
        ExpenseCategory.office => 'Office',
        ExpenseCategory.subscriptions => 'Subscriptions',
        ExpenseCategory.other => 'Other',
      };

  Color get color => switch (this) {
        ExpenseCategory.travel => AppColors.sky,
        ExpenseCategory.meals => AppColors.orange,
        ExpenseCategory.software => AppColors.violet,
        ExpenseCategory.hardware => AppColors.teal,
        ExpenseCategory.office => AppColors.amber,
        ExpenseCategory.subscriptions => AppColors.brand,
        ExpenseCategory.other => AppColors.slate,
      };

  IconData get icon => switch (this) {
        ExpenseCategory.travel => Icons.flight_takeoff_outlined,
        ExpenseCategory.meals => Icons.restaurant_outlined,
        ExpenseCategory.software => Icons.apps_outlined,
        ExpenseCategory.hardware => Icons.memory_outlined,
        ExpenseCategory.office => Icons.chair_outlined,
        ExpenseCategory.subscriptions => Icons.autorenew_outlined,
        ExpenseCategory.other => Icons.receipt_long_outlined,
      };

  String toJson() => switch (this) {
        ExpenseCategory.travel => 'travel',
        ExpenseCategory.meals => 'meals',
        ExpenseCategory.software => 'software',
        ExpenseCategory.hardware => 'hardware',
        ExpenseCategory.office => 'office',
        ExpenseCategory.subscriptions => 'subscriptions',
        ExpenseCategory.other => 'other',
      };

  factory ExpenseCategory.fromJson(String value) => switch (value) {
        'travel' => ExpenseCategory.travel,
        'meals' => ExpenseCategory.meals,
        'software' => ExpenseCategory.software,
        'hardware' => ExpenseCategory.hardware,
        'office' => ExpenseCategory.office,
        'subscriptions' => ExpenseCategory.subscriptions,
        _ => ExpenseCategory.other,
      };
}
