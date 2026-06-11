import 'package:dio/dio.dart';

import '../enums/dependency_type.dart';
import '../models/task_dependency.dart';

/// Talks to the backend's /api/v1/dependencies endpoints (AGENTS.md §1
/// `data/repositories`).
class DependenciesRepository {
  const DependenciesRepository(this._dio);

  final Dio _dio;

  /// Fetches every task dependency in the workspace.
  Future<List<TaskDependency>> list() async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/dependencies');
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) =>
            TaskDependency.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Links [predecessorId] -> [successorId]. The backend rejects cycles and
  /// auto-reschedules dependent tasks.
  Future<void> create({
    required int predecessorId,
    required int successorId,
    DependencyType type = DependencyType.finishToStart,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/dependencies',
      data: <String, dynamic>{
        'predecessor_id': predecessorId,
        'successor_id': successorId,
        'type': type.toJson(),
      },
    );
  }

  /// Removes the dependency identified by [id].
  Future<void> delete(int id) =>
      _dio.delete<void>('/api/v1/dependencies/$id');
}
