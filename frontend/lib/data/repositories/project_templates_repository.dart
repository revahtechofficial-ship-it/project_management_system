import 'package:dio/dio.dart';

import '../enums/project_status.dart';
import '../models/project_template.dart';

/// Talks to /api/v1/project-templates — reusable project blueprints.
class ProjectTemplatesRepository {
  const ProjectTemplatesRepository(this._dio);

  final Dio _dio;

  /// All saved project templates.
  Future<List<ProjectTemplate>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/project-templates',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => ProjectTemplate.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Saves the given project fields as a named template.
  Future<ProjectTemplate> create({
    required String name,
    String projectName = '',
    String description = '',
    ProjectStatus status = ProjectStatus.active,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/project-templates',
          data: <String, dynamic>{
            'name': name,
            'project_name': projectName,
            'description': description,
            'status': status.toJson(),
          },
        );
    return ProjectTemplate.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Deletes a template.
  Future<void> delete(int id) =>
      _dio.delete<void>('/api/v1/project-templates/$id');
}
