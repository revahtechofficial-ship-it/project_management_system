/// An external client, from `/api/v1/clients`. Each client has a portal token
/// that unlocks a public read-only view. Manual JSON per AGENTS.md §9.
class Client {
  final int id;
  final String name;
  final String company;
  final String email;
  final String portalToken;
  final int projectCount;
  final DateTime createdAt;

  const Client({
    required this.id,
    required this.createdAt,
    this.name = '',
    this.company = '',
    this.email = '',
    this.portalToken = '',
    this.projectCount = 0,
  });

  /// The client's display label — their name, falling back to the company.
  String get displayName =>
      name.isNotEmpty ? name : (company.isNotEmpty ? company : 'Client');

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    company: json['company'] as String? ?? '',
    email: json['email'] as String? ?? '',
    portalToken: json['portal_token'] as String? ?? '',
    projectCount: json['project_count'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'company': company,
    'email': email,
    'portal_token': portalToken,
    'project_count': projectCount,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'Client(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Client &&
          other.id == id &&
          other.name == name &&
          other.company == company &&
          other.email == email &&
          other.portalToken == portalToken &&
          other.projectCount == projectCount &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    company,
    email,
    portalToken,
    projectCount,
    createdAt,
  );
}
