import '../enums/expense_category.dart';
import '../enums/expense_status.dart';

/// One expense claim from `/api/v1/expenses` — an amount spent by a team
/// member, optionally against a project. Manual JSON serialization per
/// AGENTS.md §9.
class Expense {
  final int id;
  final int? userId;
  final String submitterName;
  final int? projectId;
  final String projectName;
  final ExpenseCategory category;
  final int amountCents;
  final DateTime? spentOn;
  final String description;
  final String merchant;
  final String receiptUrl;
  final ExpenseStatus status;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.createdAt,
    this.userId,
    this.submitterName = '',
    this.projectId,
    this.projectName = '',
    this.category = ExpenseCategory.other,
    this.amountCents = 0,
    this.spentOn,
    this.description = '',
    this.merchant = '',
    this.receiptUrl = '',
    this.status = ExpenseStatus.pending,
  });

  /// Amount in whole currency units (cents / 100).
  double get amount => amountCents / 100;

  static DateTime? _date(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as int,
        userId: json['user_id'] as int?,
        submitterName: json['submitter_name'] as String? ?? '',
        projectId: json['project_id'] as int?,
        projectName: json['project_name'] as String? ?? '',
        category:
            ExpenseCategory.fromJson(json['category'] as String? ?? 'other'),
        amountCents: json['amount_cents'] as int? ?? 0,
        spentOn: _date(json['spent_on']),
        description: json['description'] as String? ?? '',
        merchant: json['merchant'] as String? ?? '',
        receiptUrl: json['receipt_url'] as String? ?? '',
        status:
            ExpenseStatus.fromJson(json['status'] as String? ?? 'pending'),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'submitter_name': submitterName,
        'project_id': projectId,
        'project_name': projectName,
        'category': category.toJson(),
        'amount_cents': amountCents,
        'spent_on': spentOn?.toIso8601String(),
        'description': description,
        'merchant': merchant,
        'receipt_url': receiptUrl,
        'status': status.toJson(),
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() =>
      'Expense(id: $id, ${category.name}: $amountCents, ${status.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          other.id == id &&
          other.userId == userId &&
          other.submitterName == submitterName &&
          other.projectId == projectId &&
          other.projectName == projectName &&
          other.category == category &&
          other.amountCents == amountCents &&
          other.spentOn == spentOn &&
          other.description == description &&
          other.merchant == merchant &&
          other.receiptUrl == receiptUrl &&
          other.status == status &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        submitterName,
        projectId,
        projectName,
        category,
        amountCents,
        spentOn,
        description,
        merchant,
        receiptUrl,
        status,
        createdAt,
      );
}
