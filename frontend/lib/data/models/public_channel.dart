/// A public team channel a user can discover and join, from
/// `GET /api/v1/chat/channels`. Manual JSON serialization per AGENTS.md §9.
class PublicChannel {
  final int id;
  final String name;
  final String? avatarUrl;
  final int memberCount;
  final DateTime createdAt;

  const PublicChannel({
    required this.id,
    required this.createdAt,
    this.name = '',
    this.avatarUrl,
    this.memberCount = 0,
  });

  factory PublicChannel.fromJson(Map<String, dynamic> json) => PublicChannel(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    avatarUrl: json['group_avatar_url'] as String?,
    memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'group_avatar_url': avatarUrl,
    'member_count': memberCount,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'PublicChannel(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicChannel &&
          other.id == id &&
          other.name == name &&
          other.avatarUrl == avatarUrl &&
          other.memberCount == memberCount &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, avatarUrl, memberCount, createdAt);
}
