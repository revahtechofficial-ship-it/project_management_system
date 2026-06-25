/// A personal API key (token shown only once at creation), from
/// `GET /api/v1/integrations/api-keys`. Manual JSON serialization per
/// AGENTS.md §9.
class ApiKey {
  final int id;
  final String name;
  final String prefix;
  final DateTime? lastUsedAt;
  final DateTime createdAt;

  const ApiKey({
    required this.id,
    required this.createdAt,
    this.name = '',
    this.prefix = '',
    this.lastUsedAt,
  });

  factory ApiKey.fromJson(Map<String, dynamic> json) => ApiKey(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    prefix: json['prefix'] as String? ?? '',
    lastUsedAt: json['last_used_at'] == null
        ? null
        : DateTime.parse(json['last_used_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'prefix': prefix,
    'last_used_at': lastUsedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'ApiKey(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiKey &&
          other.id == id &&
          other.name == name &&
          other.prefix == prefix &&
          other.lastUsedAt == lastUsedAt &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, prefix, lastUsedAt, createdAt);
}
