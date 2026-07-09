/// One member of a project and their per-project role, from
/// `/api/v1/projects/{id}/members`. Manual JSON serialization per AGENTS.md §9.
class ProjectMember {
  final int userId;
  final String userName;
  final String userEmail;
  final String role;
  final DateTime createdAt;

  const ProjectMember({
    required this.userId,
    required this.createdAt,
    this.userName = '',
    this.userEmail = '',
    this.role = 'editor',
  });

  /// The member's display label — their name, falling back to their email.
  String get displayName => userName.isNotEmpty ? userName : userEmail;

  factory ProjectMember.fromJson(Map<String, dynamic> json) => ProjectMember(
        userId: json['user_id'] as int,
        userName: json['user_name'] as String? ?? '',
        userEmail: json['user_email'] as String? ?? '',
        role: json['role'] as String? ?? 'editor',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'role': role,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'ProjectMember(user: $userId, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectMember &&
          other.userId == userId &&
          other.userName == userName &&
          other.userEmail == userEmail &&
          other.role == role &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(userId, userName, userEmail, role, createdAt);
}

/// A project's members plus the caller's effective role on that project.
class ProjectMembership {
  final String myRole;
  final List<ProjectMember> members;

  const ProjectMembership({
    this.myRole = 'manager',
    this.members = const <ProjectMember>[],
  });

  /// Whether the caller administers the project.
  bool get canManage => myRole == 'manager';

  factory ProjectMembership.fromJson(Map<String, dynamic> json) =>
      ProjectMembership(
        myRole: json['my_role'] as String? ?? 'manager',
        members: <ProjectMember>[
          for (final dynamic e
              in (json['members'] as List<dynamic>? ?? <dynamic>[]))
            ProjectMember.fromJson(e as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'my_role': myRole,
        'members': members.map((ProjectMember m) => m.toJson()).toList(),
      };

  @override
  String toString() =>
      'ProjectMembership($myRole, ${members.length} members)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectMembership &&
          other.myRole == myRole &&
          _sameMembers(other.members, members);

  @override
  int get hashCode => Object.hash(myRole, Object.hashAll(members));

  static bool _sameMembers(List<ProjectMember> a, List<ProjectMember> b) {
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
