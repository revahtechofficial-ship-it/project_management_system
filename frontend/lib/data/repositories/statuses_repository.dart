import 'package:dio/dio.dart';

import '../models/workflow_status.dart';

/// Talks to /api/v1/statuses — the customizable task workflow states.
/// Reads are open to any user; writes are admin-only on the server.
class StatusesRepository {
  const StatusesRepository(this._dio);

  final Dio _dio;

  /// All workflow statuses, ordered by position.
  Future<List<WorkflowStatus>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/statuses',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => WorkflowStatus.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Adds a status (a key is generated from the label server-side).
  Future<WorkflowStatus> create({
    required String label,
    required String color,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/statuses',
          data: <String, dynamic>{'label': label, 'color': color},
        );
    return WorkflowStatus.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Renames / recolors / repositions a status.
  Future<void> update(
    int id, {
    required String label,
    required String color,
    required int position,
  }) => _dio.put<void>(
    '/api/v1/statuses/$id',
    data: <String, dynamic>{
      'label': label,
      'color': color,
      'position': position,
    },
  );

  /// Deletes a status (server refuses protected or in-use ones).
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/statuses/$id');

  /// Persists a new column order (ids in their desired order).
  Future<void> reorder(List<int> ids) => _dio.post<void>(
    '/api/v1/statuses/reorder',
    data: <String, dynamic>{'ids': ids},
  );

  /// Applies a named preset, adding any of its statuses that are missing.
  Future<void> applyTemplate(String template) => _dio.post<void>(
    '/api/v1/statuses/template',
    data: <String, dynamic>{'template': template},
  );
}
