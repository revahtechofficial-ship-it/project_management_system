/// A team member's planned weekly working hours, used as the denominator for
/// utilization in Resource Management. Manual JSON serialization per
/// AGENTS.md §9.
class MemberCapacity {
  final int userId;
  final String name;
  final String email;
  final int weeklyHours;

  const MemberCapacity({
    required this.userId,
    this.name = '',
    this.email = '',
    this.weeklyHours = 40,
  });

  /// The name to show, falling back to the email when unset.
  String get displayName => name.isEmpty ? email : name;

  MemberCapacity copyWith({int? weeklyHours}) => MemberCapacity(
    userId: userId,
    name: name,
    email: email,
    weeklyHours: weeklyHours ?? this.weeklyHours,
  );

  factory MemberCapacity.fromJson(Map<String, dynamic> json) => MemberCapacity(
    userId: json['user_id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    weeklyHours: (json['weekly_hours'] as num?)?.toInt() ?? 40,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'name': name,
    'email': email,
    'weekly_hours': weeklyHours,
  };

  @override
  String toString() =>
      'MemberCapacity(userId: $userId, name: $name, weeklyHours: $weeklyHours)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberCapacity &&
          other.userId == userId &&
          other.name == name &&
          other.email == email &&
          other.weeklyHours == weeklyHours;

  @override
  int get hashCode => Object.hash(userId, name, email, weeklyHours);
}
