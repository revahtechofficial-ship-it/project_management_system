/// A user a private page is shared with, from `GET /pages/{id}/shares`.
/// Manual JSON serialization per AGENTS.md §9.
class PageShare {
  final int userId;
  final String permission;
  final String fullName;
  final String email;
  final String? avatarUrl;

  const PageShare({
    required this.userId,
    this.permission = 'view',
    this.fullName = '',
    this.email = '',
    this.avatarUrl,
  });

  bool get canEdit => permission == 'edit';

  factory PageShare.fromJson(Map<String, dynamic> json) => PageShare(
    userId: json['user_id'] as int,
    permission: json['permission'] as String? ?? 'view',
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'permission': permission,
    'full_name': fullName,
    'email': email,
    'avatar_url': avatarUrl,
  };

  @override
  String toString() => 'PageShare(userId: $userId, permission: $permission)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageShare &&
          other.userId == userId &&
          other.permission == permission &&
          other.fullName == fullName &&
          other.email == email &&
          other.avatarUrl == avatarUrl;

  @override
  int get hashCode =>
      Object.hash(userId, permission, fullName, email, avatarUrl);
}
