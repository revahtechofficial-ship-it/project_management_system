/// A weekly timesheet submission (submitted → approved/rejected), from
/// `/api/v1/timesheets`. Manual JSON serialization per AGENTS.md §9.
class TimesheetSubmission {
  final int id;
  final int userId;
  final String userName;
  final DateTime weekStart;
  final String status;
  final int minutes;
  final String note;
  final String approverName;
  final DateTime? decidedAt;
  final DateTime submittedAt;

  const TimesheetSubmission({
    required this.id,
    required this.userId,
    required this.weekStart,
    required this.submittedAt,
    this.userName = '',
    this.status = 'submitted',
    this.minutes = 0,
    this.note = '',
    this.approverName = '',
    this.decidedAt,
  });

  bool get isPending => status == 'submitted';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory TimesheetSubmission.fromJson(Map<String, dynamic> json) =>
      TimesheetSubmission(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        userName: json['user_name'] as String? ?? '',
        weekStart: DateTime.parse(json['week_start'] as String),
        status: json['status'] as String? ?? 'submitted',
        minutes: json['minutes'] as int? ?? 0,
        note: json['note'] as String? ?? '',
        approverName: json['approver_name'] as String? ?? '',
        decidedAt: json['decided_at'] == null
            ? null
            : DateTime.parse(json['decided_at'] as String),
        submittedAt: DateTime.parse(json['submitted_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'week_start': weekStart.toIso8601String(),
    'status': status,
    'minutes': minutes,
    'note': note,
    'approver_name': approverName,
    'decided_at': decidedAt?.toIso8601String(),
    'submitted_at': submittedAt.toIso8601String(),
  };

  @override
  String toString() =>
      'TimesheetSubmission(id: $id, week: $weekStart, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimesheetSubmission &&
          other.id == id &&
          other.userId == userId &&
          other.userName == userName &&
          other.weekStart == weekStart &&
          other.status == status &&
          other.minutes == minutes &&
          other.note == note &&
          other.approverName == approverName &&
          other.decidedAt == decidedAt &&
          other.submittedAt == submittedAt;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    userName,
    weekStart,
    status,
    minutes,
    note,
    approverName,
    decidedAt,
    submittedAt,
  );
}
