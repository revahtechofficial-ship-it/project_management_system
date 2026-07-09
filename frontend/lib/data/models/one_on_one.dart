/// A scheduled 1:1 between a manager and a report, from
/// `/api/v1/one-on-ones`. Manual JSON serialization per AGENTS.md §9.
class OneOnOne {
  final int id;
  final int managerId;
  final String managerName;
  final int reportId;
  final String reportName;
  final DateTime scheduledAt;
  final DateTime createdAt;

  const OneOnOne({
    required this.id,
    required this.managerId,
    required this.reportId,
    required this.scheduledAt,
    required this.createdAt,
    this.managerName = '',
    this.reportName = '',
  });

  /// The name of the other participant, from [myId]'s perspective.
  String otherName(int myId) => myId == managerId ? reportName : managerName;

  /// Whether [myId] is the manager in this 1:1.
  bool isManager(int myId) => myId == managerId;

  factory OneOnOne.fromJson(Map<String, dynamic> json) => OneOnOne(
    id: json['id'] as int,
    managerId: json['manager_id'] as int,
    managerName: json['manager_name'] as String? ?? '',
    reportId: json['report_id'] as int,
    reportName: json['report_name'] as String? ?? '',
    scheduledAt: DateTime.parse(json['scheduled_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'manager_id': managerId,
    'manager_name': managerName,
    'report_id': reportId,
    'report_name': reportName,
    'scheduled_at': scheduledAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'OneOnOne(id: $id, at: $scheduledAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OneOnOne &&
          other.id == id &&
          other.managerId == managerId &&
          other.managerName == managerName &&
          other.reportId == reportId &&
          other.reportName == reportName &&
          other.scheduledAt == scheduledAt &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    managerId,
    managerName,
    reportId,
    reportName,
    scheduledAt,
    createdAt,
  );
}

/// One item in a 1:1 — an agenda point, a shared note, or an action item. The
/// [kind] is `agenda`, `note` or `action`; only actions use [done].
class OneOnOneItem {
  final int id;
  final int meetingId;
  final String authorName;
  final String kind;
  final String body;
  final bool done;
  final DateTime createdAt;

  const OneOnOneItem({
    required this.id,
    required this.meetingId,
    required this.createdAt,
    this.authorName = '',
    this.kind = 'agenda',
    this.body = '',
    this.done = false,
  });

  factory OneOnOneItem.fromJson(Map<String, dynamic> json) => OneOnOneItem(
    id: json['id'] as int,
    meetingId: json['meeting_id'] as int,
    authorName: json['author_name'] as String? ?? '',
    kind: json['kind'] as String? ?? 'agenda',
    body: json['body'] as String? ?? '',
    done: json['done'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'meeting_id': meetingId,
    'author_name': authorName,
    'kind': kind,
    'body': body,
    'done': done,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'OneOnOneItem($kind: $body)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OneOnOneItem &&
          other.id == id &&
          other.meetingId == meetingId &&
          other.authorName == authorName &&
          other.kind == kind &&
          other.body == body &&
          other.done == done &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, meetingId, authorName, kind, body, done, createdAt);
}
