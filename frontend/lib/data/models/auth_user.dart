import '../enums/member_role.dart';

/// The signed-in user returned by the BFF auth API.
///
/// Manual JSON serialization per AGENTS.md §9.
class AuthUser {
  final int id;
  final String email;
  final String name;
  final MemberRole role;

  const AuthUser({
    required this.id,
    this.email = '',
    this.name = '',
    this.role = MemberRole.member,
  });

  /// Whether this user may perform admin-only actions.
  bool get isAdmin => role.isAdmin;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: MemberRole.fromJson(json['role'] as String? ?? 'member'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'email': email,
        'name': name,
        'role': role.toJson(),
      };

  @override
  String toString() =>
      'AuthUser(id: $id, email: $email, name: $name, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.id == id &&
          other.email == email &&
          other.name == name &&
          other.role == role;

  @override
  int get hashCode => Object.hash(id, email, name, role);
}
