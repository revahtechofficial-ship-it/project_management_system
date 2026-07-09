/// A spending cap for one project, with actual cost rolled up from approved
/// expenses and billable time, from `/api/v1/budgets`. Manual JSON
/// serialization per AGENTS.md §9.
class Budget {
  final int id;
  final int projectId;
  final String projectName;
  final int amountCents;
  final int hourlyRateCents;
  final String notes;
  final int expenseCents;
  final int billableMinutes;
  final int laborCents;
  final int actualCents;
  final DateTime updatedAt;

  const Budget({
    required this.id,
    required this.projectId,
    required this.updatedAt,
    this.projectName = '',
    this.amountCents = 0,
    this.hourlyRateCents = 0,
    this.notes = '',
    this.expenseCents = 0,
    this.billableMinutes = 0,
    this.laborCents = 0,
    this.actualCents = 0,
  });

  /// Budget left after actual cost; negative when over budget.
  int get remainingCents => amountCents - actualCents;

  /// Billable hours logged against the project.
  double get billableHours => billableMinutes / 60;

  /// Fraction of the budget consumed, in `0.0`–`1.0` (clamped for display).
  double get usedFraction {
    if (amountCents <= 0) {
      return 0;
    }
    final double f = actualCents / amountCents;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }

  /// True when actual cost has exceeded the budget.
  bool get overBudget => amountCents > 0 && actualCents > amountCents;

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    id: json['id'] as int,
    projectId: json['project_id'] as int,
    projectName: json['project_name'] as String? ?? '',
    amountCents: json['amount_cents'] as int? ?? 0,
    hourlyRateCents: json['hourly_rate_cents'] as int? ?? 0,
    notes: json['notes'] as String? ?? '',
    expenseCents: json['expense_cents'] as int? ?? 0,
    billableMinutes: json['billable_minutes'] as int? ?? 0,
    laborCents: json['labor_cents'] as int? ?? 0,
    actualCents: json['actual_cents'] as int? ?? 0,
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'project_id': projectId,
    'project_name': projectName,
    'amount_cents': amountCents,
    'hourly_rate_cents': hourlyRateCents,
    'notes': notes,
    'expense_cents': expenseCents,
    'billable_minutes': billableMinutes,
    'labor_cents': laborCents,
    'actual_cents': actualCents,
    'updated_at': updatedAt.toIso8601String(),
  };

  @override
  String toString() =>
      'Budget(project: $projectName, $actualCents / $amountCents)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Budget &&
          other.id == id &&
          other.projectId == projectId &&
          other.projectName == projectName &&
          other.amountCents == amountCents &&
          other.hourlyRateCents == hourlyRateCents &&
          other.notes == notes &&
          other.expenseCents == expenseCents &&
          other.billableMinutes == billableMinutes &&
          other.laborCents == laborCents &&
          other.actualCents == actualCents &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    projectName,
    amountCents,
    hourlyRateCents,
    notes,
    expenseCents,
    billableMinutes,
    laborCents,
    actualCents,
    updatedAt,
  );
}
