import '../enums/incident_kind.dart';
import '../enums/incident_severity.dart';
import '../enums/incident_status.dart';

/// A tracked bug or operational incident from `/api/v1/incidents`, with
/// severity, triage status and assignment. Manual JSON serialization per
/// AGENTS.md §9.
class Incident {
  final int id;
  final String title;
  final String description;
  final IncidentKind kind;
  final IncidentSeverity severity;
  final IncidentStatus status;
  final int? projectId;
  final String projectName;
  final int? assigneeId;
  final String assigneeName;
  final int? reporterId;
  final String reporterName;
  final String component;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  const Incident({
    required this.id,
    required this.createdAt,
    this.title = '',
    this.description = '',
    this.kind = IncidentKind.bug,
    this.severity = IncidentSeverity.medium,
    this.status = IncidentStatus.open,
    this.projectId,
    this.projectName = '',
    this.assigneeId,
    this.assigneeName = '',
    this.reporterId,
    this.reporterName = '',
    this.component = '',
    this.resolvedAt,
  });

  static DateTime? _date(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        kind: IncidentKind.fromJson(json['kind'] as String? ?? 'bug'),
        severity:
            IncidentSeverity.fromJson(json['severity'] as String? ?? 'medium'),
        status: IncidentStatus.fromJson(json['status'] as String? ?? 'open'),
        projectId: json['project_id'] as int?,
        projectName: json['project_name'] as String? ?? '',
        assigneeId: json['assignee_id'] as int?,
        assigneeName: json['assignee_name'] as String? ?? '',
        reporterId: json['reporter_id'] as int?,
        reporterName: json['reporter_name'] as String? ?? '',
        component: json['component'] as String? ?? '',
        resolvedAt: _date(json['resolved_at']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'kind': kind.toJson(),
        'severity': severity.toJson(),
        'status': status.toJson(),
        'project_id': projectId,
        'project_name': projectName,
        'assignee_id': assigneeId,
        'assignee_name': assigneeName,
        'reporter_id': reporterId,
        'reporter_name': reporterName,
        'component': component,
        'resolved_at': resolvedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() =>
      'Incident(id: $id, ${severity.name} ${kind.name}: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Incident &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.kind == kind &&
          other.severity == severity &&
          other.status == status &&
          other.projectId == projectId &&
          other.projectName == projectName &&
          other.assigneeId == assigneeId &&
          other.assigneeName == assigneeName &&
          other.reporterId == reporterId &&
          other.reporterName == reporterName &&
          other.component == component &&
          other.resolvedAt == resolvedAt &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        title,
        description,
        kind,
        severity,
        status,
        projectId,
        projectName,
        assigneeId,
        assigneeName,
        reporterId,
        reporterName,
        component,
        resolvedAt,
        createdAt,
      ]);
}
