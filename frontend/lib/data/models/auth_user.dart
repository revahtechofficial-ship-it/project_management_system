/// The signed-in user returned by the BFF auth API.
///
/// Manual JSON serialization per AGENTS.md §9.
class AuthUser {
  final int id;
  final String email;
  final String name;

  const AuthUser({
    required this.id,
    this.email = '',
    this.name = '',
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'email': email,
        'name': name,
      };

  @override
  String toString() => 'AuthUser(id: $id, email: $email, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.id == id &&
          other.email == email &&
          other.name == name;

  @override
  int get hashCode => Object.hash(id, email, name);
}
