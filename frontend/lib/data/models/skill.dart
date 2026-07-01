/// A skill a team member has, with a proficiency [level] (1–5), from
/// `/api/v1/skills`. Manual JSON serialization per AGENTS.md §9.
class Skill {
  final int id;
  final int userId;
  final String userName;
  final String? avatarUrl;
  final String skill;
  final int level;

  const Skill({
    required this.id,
    required this.userId,
    this.userName = '',
    this.avatarUrl,
    this.skill = '',
    this.level = 3,
  });

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        userName: json['user_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        skill: json['skill'] as String? ?? '',
        level: json['level'] as int? ?? 3,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'user_name': userName,
        'avatar_url': avatarUrl,
        'skill': skill,
        'level': level,
      };

  @override
  String toString() => 'Skill($skill L$level u$userId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Skill &&
          other.id == id &&
          other.userId == userId &&
          other.userName == userName &&
          other.avatarUrl == avatarUrl &&
          other.skill == skill &&
          other.level == level;

  @override
  int get hashCode =>
      Object.hash(id, userId, userName, avatarUrl, skill, level);
}
