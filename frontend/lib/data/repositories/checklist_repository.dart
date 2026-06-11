import 'package:dio/dio.dart';

import '../models/checklist_item.dart';

/// Talks to the backend's checklist endpoints (AGENTS.md §1
/// `data/repositories`).
class ChecklistRepository {
  const ChecklistRepository(this._dio);

  final Dio _dio;

  /// Lists the checklist items of a task.
  Future<List<ChecklistItem>> list(int taskId) async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/tasks/$taskId/checklist');
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Adds a checklist item to a task.
  Future<void> add(int taskId, String content) =>
      _dio.post<Map<String, dynamic>>(
        '/api/v1/tasks/$taskId/checklist',
        data: <String, dynamic>{'content': content},
      );

  /// Toggles a checklist item's done state.
  Future<void> setDone(int itemId, bool done) =>
      _dio.patch<Map<String, dynamic>>(
        '/api/v1/tasks/checklist/$itemId',
        data: <String, dynamic>{'done': done},
      );

  /// Deletes a checklist item.
  Future<void> delete(int itemId) =>
      _dio.delete<void>('/api/v1/tasks/checklist/$itemId');
}
