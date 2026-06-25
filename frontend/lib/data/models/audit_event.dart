/// A security/administration audit log entry, from
/// `GET /api/v1/admin/audit-log`. Manual JSON serialization per AGENTS.md §9.
class AuditEvent {
  final int id;
  final String actorName;
  final String action;
  final String target;
  final String detail;
  final DateTime createdAt;

  const AuditEvent({
    required this.id,
    required this.createdAt,
    this.actorName = '',
    this.action = '',
    this.target = '',
    this.detail = '',
  });

  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
    id: json['id'] as int,
    actorName: json['actor_name'] as String? ?? '',
    action: json['action'] as String? ?? '',
    target: json['target'] as String? ?? '',
    detail: json['detail'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'actor_name': actorName,
    'action': action,
    'target': target,
    'detail': detail,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'AuditEvent(id: $id, action: $action)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditEvent &&
          other.id == id &&
          other.actorName == actorName &&
          other.action == action &&
          other.target == target &&
          other.detail == detail &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, actorName, action, target, detail, createdAt);
}
