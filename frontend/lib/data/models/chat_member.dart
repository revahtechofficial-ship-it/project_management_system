/// A member of a chat conversation, from `GET /conversations/{id}/members`.
/// Manual JSON per AGENTS.md §9.
class ChatMember {
  final int userId;
  final String role;
  final String fullName;
  final String email;
  final String? avatarUrl;

  const ChatMember({
    required this.userId,
    this.role = 'member',
    this.fullName = '',
    this.email = '',
    this.avatarUrl,
  });

  bool get isAdmin => role == 'admin';

  factory ChatMember.fromJson(Map<String, dynamic> json) => ChatMember(
        userId: json['user_id'] as int,
        role: json['role'] as String? ?? 'member',
        fullName: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user_id': userId,
        'role': role,
        'full_name': fullName,
        'email': email,
        'avatar_url': avatarUrl,
      };

  @override
  String toString() => 'ChatMember(userId: $userId, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMember &&
          other.userId == userId &&
          other.role == role &&
          other.fullName == fullName &&
          other.email == email &&
          other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(userId, role, fullName, email, avatarUrl);
}
