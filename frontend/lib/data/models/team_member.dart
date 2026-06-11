import '../enums/member_role.dart';

/// A workspace member (a registered user with aggregated task counts), as
/// returned by `GET /api/v1/team`. Manual JSON serialization per AGENTS.md §9.
class TeamMember {
  final int id;
  final String name;
  final String email;
  final MemberRole role;
  final int openTasks;
  final int completedTasks;
  final DateTime createdAt;

  const TeamMember({
    required this.id,
    required this.role,
    required this.createdAt,
    this.name = '',
    this.email = '',
    this.openTasks = 0,
    this.completedTasks = 0,
  });

  int get totalTasks => openTasks + completedTasks;

  /// Fraction of this member's tasks that are complete, in `0.0`–`1.0`.
  double get progress => totalTasks == 0 ? 0 : completedTasks / totalTasks;

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        id: json['id'] as int,
        name: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: MemberRole.fromJson(json['role'] as String? ?? ''),
        openTasks: json['open_tasks'] as int? ?? 0,
        completedTasks: json['completed_tasks'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'full_name': name,
        'email': email,
        'role': role.toJson(),
        'open_tasks': openTasks,
        'completed_tasks': completedTasks,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'TeamMember('
      'id: $id, name: $name, email: $email, role: $role, '
      'openTasks: $openTasks, completedTasks: $completedTasks)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamMember &&
          other.id == id &&
          other.name == name &&
          other.email == email &&
          other.role == role &&
          other.openTasks == openTasks &&
          other.completedTasks == completedTasks &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        email,
        role,
        openTasks,
        completedTasks,
        createdAt,
      );
}
