import 'package:dio/dio.dart';

import '../models/task.dart';

/// Talks to the backend's /api/v1/tasks endpoints.
class TasksRepository {
  TasksRepository(this._dio);

  final Dio _dio;

  Future<List<Task>> list() async {
    final res = await _dio.get<List<dynamic>>('/api/v1/tasks');
    final data = res.data ?? <dynamic>[];
    return data
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Task> create({required String title, String description = ''}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/tasks',
      data: {'title': title, 'description': description},
    );
    return Task.fromJson(res.data!);
  }

  Future<Task> setDone(int id, {required bool done}) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/tasks/$id',
      data: {'done': done},
    );
    return Task.fromJson(res.data!);
  }

  Future<void> delete(int id) => _dio.delete<void>('/api/v1/tasks/$id');
}
