import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Workflow state of an [Invoice]. Tied to the model, so it carries
/// `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum InvoiceStatus {
  draft,
  sent,
  paid,
  void_;

  String get label => switch (this) {
        InvoiceStatus.draft => 'Draft',
        InvoiceStatus.sent => 'Sent',
        InvoiceStatus.paid => 'Paid',
        InvoiceStatus.void_ => 'Void',
      };

  Color get color => switch (this) {
        InvoiceStatus.draft => AppColors.slate,
        InvoiceStatus.sent => AppColors.sky,
        InvoiceStatus.paid => AppColors.green,
        InvoiceStatus.void_ => AppColors.rose,
      };

  String toJson() => switch (this) {
        InvoiceStatus.draft => 'draft',
        InvoiceStatus.sent => 'sent',
        InvoiceStatus.paid => 'paid',
        InvoiceStatus.void_ => 'void',
      };

  factory InvoiceStatus.fromJson(String value) => switch (value) {
        'sent' => InvoiceStatus.sent,
        'paid' => InvoiceStatus.paid,
        'void' => InvoiceStatus.void_,
        _ => InvoiceStatus.draft,
      };
}
