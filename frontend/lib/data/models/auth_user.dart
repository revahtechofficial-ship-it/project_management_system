import '../enums/member_role.dart';

/// The signed-in user returned by the BFF auth API.
///
/// Manual JSON serialization per AGENTS.md §9.
class AuthUser {
  final int id;
  final String email;
  final String name;
  final MemberRole role;
  final String? avatarUrl;
  final String phone;
  final String jobTitle;
  final String department;
  final String location;
  final String bio;

  const AuthUser({
    required this.id,
    this.email = '',
    this.name = '',
    this.role = MemberRole.member,
    this.avatarUrl,
    this.phone = '',
    this.jobTitle = '',
    this.department = '',
    this.location = '',
    this.bio = '',
  });

  /// Whether this user may perform admin-only actions.
  bool get isAdmin => role.isAdmin;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: MemberRole.fromJson(json['role'] as String? ?? 'member'),
        avatarUrl: json['avatar_url'] as String?,
        phone: json['phone'] as String? ?? '',
        jobTitle: json['job_title'] as String? ?? '',
        department: json['department'] as String? ?? '',
        location: json['location'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'email': email,
        'name': name,
        'role': role.toJson(),
        'avatar_url': avatarUrl,
        'phone': phone,
        'job_title': jobTitle,
        'department': department,
        'location': location,
        'bio': bio,
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
          other.role == role &&
          other.avatarUrl == avatarUrl &&
          other.phone == phone &&
          other.jobTitle == jobTitle &&
          other.department == department &&
          other.location == location &&
          other.bio == bio;

  @override
  int get hashCode => Object.hash(id, email, name, role, avatarUrl, phone,
      jobTitle, department, location, bio);
}
