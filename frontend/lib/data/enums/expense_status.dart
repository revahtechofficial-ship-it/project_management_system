import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Workflow state of an [Expense] claim. Tied to the model, so it carries
/// `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum ExpenseStatus {
  pending,
  approved,
  rejected,
  reimbursed;

  String get label => switch (this) {
        ExpenseStatus.pending => 'Pending',
        ExpenseStatus.approved => 'Approved',
        ExpenseStatus.rejected => 'Rejected',
        ExpenseStatus.reimbursed => 'Reimbursed',
      };

  Color get color => switch (this) {
        ExpenseStatus.pending => AppColors.amber,
        ExpenseStatus.approved => AppColors.green,
        ExpenseStatus.rejected => AppColors.rose,
        ExpenseStatus.reimbursed => AppColors.brand,
      };

  String toJson() => switch (this) {
        ExpenseStatus.pending => 'pending',
        ExpenseStatus.approved => 'approved',
        ExpenseStatus.rejected => 'rejected',
        ExpenseStatus.reimbursed => 'reimbursed',
      };

  factory ExpenseStatus.fromJson(String value) => switch (value) {
        'approved' => ExpenseStatus.approved,
        'rejected' => ExpenseStatus.rejected,
        'reimbursed' => ExpenseStatus.reimbursed,
        _ => ExpenseStatus.pending,
      };
}
