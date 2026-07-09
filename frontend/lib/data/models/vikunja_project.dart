/// A Vikunja project (subset), fetched through the BFF.
///
/// Manual JSON serialization per AGENTS.md §9. snake_case keys match Vikunja.
class VikunjaProject {
  final int id;
  final String title;
  final String description;
  final bool isArchived;

  const VikunjaProject({
    required this.id,
    required this.isArchived,
    this.title = '',
    this.description = '',
  });

  factory VikunjaProject.fromJson(Map<String, dynamic> json) => VikunjaProject(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    isArchived: json['is_archived'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'is_archived': isArchived,
  };

  @override
  String toString() =>
      'VikunjaProject('
      'id: $id, title: $title, description: $description, '
      'isArchived: $isArchived)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VikunjaProject &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.isArchived == isArchived;

  @override
  int get hashCode => Object.hash(id, title, description, isArchived);
}
