import '../enums/project_status.dart';

/// A reusable project blueprint, from `GET /api/v1/project-templates`. The
/// New-project form is pre-filled from one. Manual JSON serialization (§9).
class ProjectTemplate {
  final int id;
  final String name;
  final String projectName;
  final String description;
  final ProjectStatus status;

  const ProjectTemplate({
    required this.id,
    this.name = '',
    this.projectName = '',
    this.description = '',
    this.status = ProjectStatus.active,
  });

  factory ProjectTemplate.fromJson(Map<String, dynamic> json) =>
      ProjectTemplate(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        projectName: json['project_name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: ProjectStatus.fromJson(json['status'] as String? ?? 'active'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'project_name': projectName,
    'description': description,
    'status': status.toJson(),
  };

  @override
  String toString() => 'ProjectTemplate(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectTemplate &&
          other.id == id &&
          other.name == name &&
          other.projectName == projectName &&
          other.description == description &&
          other.status == status;

  @override
  int get hashCode => Object.hash(id, name, projectName, description, status);
}
