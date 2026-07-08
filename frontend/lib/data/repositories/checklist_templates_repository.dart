import 'package:dio/dio.dart';

import '../models/checklist_template.dart';

/// Talks to /api/v1/checklist-templates — reusable checklists (AGENTS.md §1
/// `data/repositories`).
class ChecklistTemplatesRepository {
  const ChecklistTemplatesRepository(this._dio);

  final Dio _dio;

  /// All checklist templates, grouped-friendly (ordered by category).
  Future<List<ChecklistTemplate>> list() async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/checklist-templates');
    return <ChecklistTemplate>[
      for (final dynamic e in res.data ?? <dynamic>[])
        ChecklistTemplate.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Creates a checklist template.
  Future<void> create({
    required String name,
    String category = '',
    List<String> items = const <String>[],
  }) =>
      _dio.post<void>(
        '/api/v1/checklist-templates',
        data: <String, dynamic>{
          'name': name,
          'category': category,
          'items': items,
        },
      );

  /// Saves edits to a checklist template.
  Future<void> update(
    int id, {
    required String name,
    String category = '',
    List<String> items = const <String>[],
  }) =>
      _dio.put<void>(
        '/api/v1/checklist-templates/$id',
        data: <String, dynamic>{
          'name': name,
          'category': category,
          'items': items,
        },
      );

  /// Deletes a checklist template.
  Future<void> delete(int id) =>
      _dio.delete<void>('/api/v1/checklist-templates/$id');

  /// Appends a template's items to a task's checklist. Returns the number
  /// of items added.
  Future<int> apply(int id, int taskId) async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      '/api/v1/checklist-templates/$id/apply',
      data: <String, dynamic>{'task_id': taskId},
    );
    return (res.data?['added'] as int?) ?? 0;
  }
}
