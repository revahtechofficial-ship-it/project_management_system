import 'package:dio/dio.dart';

import '../../core/utils/api_exception.dart';
import '../models/task.dart';

/// Talks to the backend's /api/v1/tasks endpoints (AGENTS.md §1
/// `data/repositories`, §9 data abstraction).
class TasksRepository {
  const TasksRepository(this._dio);

  final Dio _dio;

  /// Fetches all tasks, newest first.
  Future<List<Task>> list() async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/tasks');
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Task.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Creates a task with the given [title] and optional [description].
  Future<Task> create({required String title, String description = ''}) async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      '/api/v1/tasks',
      data: <String, dynamic>{'title': title, 'description': description},
    );
    return _taskFrom(res);
  }

  /// Sets the `done` flag of the task identified by [id].
  Future<Task> setDone(int id, {required bool done}) async {
    final Response<Map<String, dynamic>> res =
        await _dio.patch<Map<String, dynamic>>(
      '/api/v1/tasks/$id',
      data: <String, dynamic>{'done': done},
    );
    return _taskFrom(res);
  }

  /// Deletes the task identified by [id].
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/tasks/$id');
}

/// Parses a [Task] from a response body, throwing [ApiException] when the body
/// is missing — avoids a `!` non-null assertion (AGENTS.md §6).
Task _taskFrom(Response<Map<String, dynamic>> res) {
  final Map<String, dynamic>? data = res.data;
  if (data == null) {
    final Uri uri = res.requestOptions.uri;
    throw ApiException('Empty task response from $uri');
  }
  return Task.fromJson(data);
}
