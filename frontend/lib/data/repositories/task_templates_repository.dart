import 'package:dio/dio.dart';

import '../enums/recurrence_type.dart';
import '../enums/task_priority.dart';
import '../models/task_template.dart';

/// Talks to /api/v1/task-templates — reusable task blueprints.
class TaskTemplatesRepository {
  const TaskTemplatesRepository(this._dio);

  final Dio _dio;

  /// All saved task templates.
  Future<List<TaskTemplate>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/task-templates',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => TaskTemplate.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Saves the given task fields as a named template.
  Future<TaskTemplate> create({
    required String name,
    String title = '',
    String description = '',
    String statusKey = 'todo',
    TaskPriority priority = TaskPriority.none,
    RecurrenceType recurrence = RecurrenceType.none,
    int estimateMinutes = 0,
    List<String> tags = const <String>[],
    int? projectId,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/task-templates',
          data: <String, dynamic>{
            'name': name,
            'title': title,
            'description': description,
            'status': statusKey,
            'priority': priority.toJson(),
            'recurrence': recurrence.toJson(),
            'estimate_minutes': estimateMinutes,
            'tags': tags,
            'project_id': projectId,
          },
        );
    return TaskTemplate.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Deletes a template.
  Future<void> delete(int id) =>
      _dio.delete<void>('/api/v1/task-templates/$id');
}
