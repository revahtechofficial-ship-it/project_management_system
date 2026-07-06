import '../enums/invoice_status.dart';
import 'invoice_line.dart';

/// An invoice billed from a project's time (or built by hand), from
/// `/api/v1/invoices`. The list endpoint omits [lines]; the detail endpoint
/// includes them. Manual JSON serialization per AGENTS.md §9.
class Invoice {
  final int id;
  final String number;
  final int? projectId;
  final String projectName;
  final String clientName;
  final String clientEmail;
  final InvoiceStatus status;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String notes;
  final int totalCents;
  final int lineCount;
  final DateTime createdAt;
  final List<InvoiceLine> lines;

  const Invoice({
    required this.id,
    required this.createdAt,
    this.number = '',
    this.projectId,
    this.projectName = '',
    this.clientName = '',
    this.clientEmail = '',
    this.status = InvoiceStatus.draft,
    this.issueDate,
    this.dueDate,
    this.notes = '',
    this.totalCents = 0,
    this.lineCount = 0,
    this.lines = const <InvoiceLine>[],
  });

  static DateTime? _date(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'] as int,
        number: json['number'] as String? ?? '',
        projectId: json['project_id'] as int?,
        projectName: json['project_name'] as String? ?? '',
        clientName: json['client_name'] as String? ?? '',
        clientEmail: json['client_email'] as String? ?? '',
        status: InvoiceStatus.fromJson(json['status'] as String? ?? 'draft'),
        issueDate: _date(json['issue_date']),
        dueDate: _date(json['due_date']),
        notes: json['notes'] as String? ?? '',
        totalCents: json['total_cents'] as int? ?? 0,
        lineCount: json['line_count'] as int? ?? 0,
        lines: <InvoiceLine>[
          for (final dynamic e in (json['lines'] as List<dynamic>? ??
              <dynamic>[]))
            InvoiceLine.fromJson(e as Map<String, dynamic>),
        ],
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'number': number,
        'project_id': projectId,
        'project_name': projectName,
        'client_name': clientName,
        'client_email': clientEmail,
        'status': status.toJson(),
        'issue_date': issueDate?.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'notes': notes,
        'total_cents': totalCents,
        'line_count': lineCount,
        'lines': lines.map((InvoiceLine l) => l.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'Invoice($number, ${status.name}, $totalCents)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Invoice &&
          other.id == id &&
          other.number == number &&
          other.projectId == projectId &&
          other.projectName == projectName &&
          other.clientName == clientName &&
          other.clientEmail == clientEmail &&
          other.status == status &&
          other.issueDate == issueDate &&
          other.dueDate == dueDate &&
          other.notes == notes &&
          other.totalCents == totalCents &&
          other.lineCount == lineCount &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        number,
        projectId,
        projectName,
        clientName,
        clientEmail,
        status,
        issueDate,
        dueDate,
        notes,
        totalCents,
        lineCount,
        createdAt,
      ]);
}
