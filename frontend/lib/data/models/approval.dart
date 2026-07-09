/// A sign-off request on a task/page/release (pending → approved/rejected),
/// from `/api/v1/approvals`. Manual JSON serialization per AGENTS.md §9.
class Approval {
  final int id;
  final String subjectType;
  final int subjectId;
  final String subjectTitle;
  final int requesterId;
  final String requesterName;
  final int approverId;
  final String approverName;
  final String status;
  final String note;
  final DateTime? decidedAt;
  final DateTime createdAt;

  const Approval({
    required this.id,
    required this.subjectId,
    required this.requesterId,
    required this.approverId,
    required this.createdAt,
    this.subjectType = 'task',
    this.subjectTitle = '',
    this.requesterName = '',
    this.approverName = '',
    this.status = 'pending',
    this.note = '',
    this.decidedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory Approval.fromJson(Map<String, dynamic> json) => Approval(
    id: json['id'] as int,
    subjectType: json['subject_type'] as String? ?? 'task',
    subjectId: json['subject_id'] as int,
    subjectTitle: json['subject_title'] as String? ?? '',
    requesterId: json['requester_id'] as int,
    requesterName: json['requester_name'] as String? ?? '',
    approverId: json['approver_id'] as int,
    approverName: json['approver_name'] as String? ?? '',
    status: json['status'] as String? ?? 'pending',
    note: json['note'] as String? ?? '',
    decidedAt: json['decided_at'] == null
        ? null
        : DateTime.parse(json['decided_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'subject_type': subjectType,
    'subject_id': subjectId,
    'subject_title': subjectTitle,
    'requester_id': requesterId,
    'requester_name': requesterName,
    'approver_id': approverId,
    'approver_name': approverName,
    'status': status,
    'note': note,
    'decided_at': decidedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'Approval(id: $id, $subjectType#$subjectId, $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Approval &&
          other.id == id &&
          other.subjectType == subjectType &&
          other.subjectId == subjectId &&
          other.subjectTitle == subjectTitle &&
          other.requesterId == requesterId &&
          other.requesterName == requesterName &&
          other.approverId == approverId &&
          other.approverName == approverName &&
          other.status == status &&
          other.note == note &&
          other.decidedAt == decidedAt &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    subjectType,
    subjectId,
    subjectTitle,
    requesterId,
    requesterName,
    approverId,
    approverName,
    status,
    note,
    decidedAt,
    createdAt,
  );
}
