import 'invoice.dart';
import 'project.dart';

/// The payload behind a client portal (`/api/v1/portal/{token}`): the client's
/// projects and invoices, read-only. Reuses [Project] and [Invoice]. Manual
/// JSON per AGENTS.md §9.
class PortalData {
  final String clientName;
  final String clientCompany;
  final String clientEmail;
  final List<Project> projects;
  final List<Invoice> invoices;
  final int outstandingCents;

  const PortalData({
    this.clientName = '',
    this.clientCompany = '',
    this.clientEmail = '',
    this.projects = const <Project>[],
    this.invoices = const <Invoice>[],
    this.outstandingCents = 0,
  });

  /// The heading to show the client — their company, falling back to name.
  String get heading => clientCompany.isNotEmpty
      ? clientCompany
      : (clientName.isNotEmpty ? clientName : 'Client portal');

  factory PortalData.fromJson(Map<String, dynamic> json) => PortalData(
    clientName: json['client_name'] as String? ?? '',
    clientCompany: json['client_company'] as String? ?? '',
    clientEmail: json['client_email'] as String? ?? '',
    projects: <Project>[
      for (final dynamic e
          in (json['projects'] as List<dynamic>? ?? <dynamic>[]))
        Project.fromJson(e as Map<String, dynamic>),
    ],
    invoices: <Invoice>[
      for (final dynamic e
          in (json['invoices'] as List<dynamic>? ?? <dynamic>[]))
        Invoice.fromJson(e as Map<String, dynamic>),
    ],
    outstandingCents: json['outstanding_cents'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'client_name': clientName,
    'client_company': clientCompany,
    'client_email': clientEmail,
    'projects': projects.map((Project p) => p.toJson()).toList(),
    'invoices': invoices.map((Invoice i) => i.toJson()).toList(),
    'outstanding_cents': outstandingCents,
  };

  @override
  String toString() =>
      'PortalData($heading, ${projects.length} projects, '
      '${invoices.length} invoices)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortalData &&
          other.clientName == clientName &&
          other.clientCompany == clientCompany &&
          other.clientEmail == clientEmail &&
          other.outstandingCents == outstandingCents &&
          _listEq(other.projects, projects) &&
          _listEq(other.invoices, invoices);

  @override
  int get hashCode => Object.hash(
    clientName,
    clientCompany,
    clientEmail,
    outstandingCents,
    Object.hashAll(projects),
    Object.hashAll(invoices),
  );

  static bool _listEq(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
