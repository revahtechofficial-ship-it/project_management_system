import 'package:dio/dio.dart';

import '../../core/utils/api_exception.dart';
import '../enums/project_status.dart';
import '../models/project.dart';

/// Talks to the backend's /api/v1/projects endpoints (AGENTS.md §1
/// `data/repositories`, §9 data abstraction).
class ProjectsRepository {
  const ProjectsRepository(this._dio);

  final Dio _dio;

  /// Fetches all projects with aggregated task counts and members.
  Future<List<Project>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/projects',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Project.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Creates a project. [dueDate] is sent as a `YYYY-MM-DD` string.
  Future<Project> create({
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? dueDate,
    int? spaceId,
    int? folderId,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/projects',
          data: <String, dynamic>{
            'name': name,
            'description': description,
            'status': status.toJson(),
            'due_date': _dateOnly(dueDate),
            'space_id': spaceId,
            'folder_id': folderId,
          },
        );
    return _projectFrom(res);
  }

  /// Updates an existing project.
  Future<Project> update(
    int id, {
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? dueDate,
    int? spaceId,
    int? folderId,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .put<Map<String, dynamic>>(
          '/api/v1/projects/$id',
          data: <String, dynamic>{
            'name': name,
            'description': description,
            'status': status.toJson(),
            'due_date': _dateOnly(dueDate),
            'space_id': spaceId,
            'folder_id': folderId,
          },
        );
    return _projectFrom(res);
  }

  /// Deletes the project identified by [id].
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/projects/$id');
}

String? _dateOnly(DateTime? d) {
  if (d == null) {
    return null;
  }
  final String mm = d.month.toString().padLeft(2, '0');
  final String dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

Project _projectFrom(Response<Map<String, dynamic>> res) {
  final Map<String, dynamic>? data = res.data;
  if (data == null) {
    throw ApiException('Empty project response from ${res.requestOptions.uri}');
  }
  return Project.fromJson(data);
}
