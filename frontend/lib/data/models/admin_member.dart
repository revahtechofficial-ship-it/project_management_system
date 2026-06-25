import '../enums/member_role.dart';

/// A workspace member as seen in the admin console, from
/// `GET /api/v1/admin/members`. Manual JSON serialization per AGENTS.md §9.
class AdminMember {
  final int id;
  final String email;
  final String fullName;
  final MemberRole role;
  final String? avatarUrl;
  final bool isActive;
  final bool twoFactorEnabled;
  final DateTime createdAt;

  const AdminMember({
    required this.id,
    required this.createdAt,
    this.email = '',
    this.fullName = '',
    this.role = MemberRole.member,
    this.avatarUrl,
    this.isActive = true,
    this.twoFactorEnabled = false,
  });

  String get displayName => fullName.isEmpty ? email : fullName;

  factory AdminMember.fromJson(Map<String, dynamic> json) => AdminMember(
    id: json['id'] as int,
    email: json['email'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    role: MemberRole.fromJson(json['role'] as String? ?? 'member'),
    avatarUrl: json['avatar_url'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'email': email,
    'full_name': fullName,
    'role': role.toJson(),
    'avatar_url': avatarUrl,
    'is_active': isActive,
    'two_factor_enabled': twoFactorEnabled,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'AdminMember(id: $id, email: $email, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminMember &&
          other.id == id &&
          other.email == email &&
          other.fullName == fullName &&
          other.role == role &&
          other.isActive == isActive &&
          other.twoFactorEnabled == twoFactorEnabled &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    email,
    fullName,
    role,
    isActive,
    twoFactorEnabled,
    createdAt,
  );
}
