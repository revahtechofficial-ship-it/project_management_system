import '../enums/leave_type.dart';

/// A time-off request (pending → approved/rejected), from `/api/v1/leave`.
/// Manual JSON serialization per AGENTS.md §9.
class LeaveRequest {
  final int id;
  final int userId;
  final String userName;
  final String? avatarUrl;
  final LeaveType type;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String note;
  final String approverName;
  final DateTime? decidedAt;
  final DateTime createdAt;

  const LeaveRequest({
    required this.id,
    required this.userId,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.userName = '',
    this.avatarUrl,
    this.type = LeaveType.vacation,
    this.status = 'pending',
    this.note = '',
    this.approverName = '',
    this.decidedAt,
  });

  /// Inclusive number of days off.
  int get days => endDate.difference(startDate).inDays + 1;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
    id: json['id'] as int,
    userId: json['user_id'] as int,
    userName: json['user_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    type: LeaveType.fromJson(json['type'] as String? ?? 'vacation'),
    startDate: DateTime.parse(json['start_date'] as String),
    endDate: DateTime.parse(json['end_date'] as String),
    status: json['status'] as String? ?? 'pending',
    note: json['note'] as String? ?? '',
    approverName: json['approver_name'] as String? ?? '',
    decidedAt: json['decided_at'] == null
        ? null
        : DateTime.parse(json['decided_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'avatar_url': avatarUrl,
    'type': type.toJson(),
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'status': status,
    'note': note,
    'approver_name': approverName,
    'decided_at': decidedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'LeaveRequest(id: $id, ${type.name}, $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaveRequest &&
          other.id == id &&
          other.userId == userId &&
          other.userName == userName &&
          other.avatarUrl == avatarUrl &&
          other.type == type &&
          other.startDate == startDate &&
          other.endDate == endDate &&
          other.status == status &&
          other.note == note &&
          other.approverName == approverName &&
          other.decidedAt == decidedAt &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    userName,
    avatarUrl,
    type,
    startDate,
    endDate,
    status,
    note,
    approverName,
    decidedAt,
    createdAt,
  );
}
