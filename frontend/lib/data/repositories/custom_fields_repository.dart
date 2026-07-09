import 'package:dio/dio.dart';

import '../enums/custom_field_type.dart';
import '../models/custom_field.dart';

/// Talks to the custom-field endpoints: workspace field definitions plus the
/// per-task values (AGENTS.md §1 `data/repositories`).
class CustomFieldsRepository {
  const CustomFieldsRepository(this._dio);

  final Dio _dio;

  /// All workspace custom-field definitions.
  Future<List<CustomField>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/custom-fields',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => CustomField.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Creates a field definition (admin only on the server).
  Future<CustomField> create({
    required String name,
    required CustomFieldType type,
    List<String> options = const <String>[],
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/custom-fields',
          data: <String, dynamic>{
            'name': name,
            'type': type.toJson(),
            'options': options,
          },
        );
    return CustomField.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Renames a field or changes its options (admin only).
  Future<void> update(
    int id, {
    required String name,
    List<String> options = const <String>[],
  }) => _dio.put<void>(
    '/api/v1/custom-fields/$id',
    data: <String, dynamic>{'name': name, 'options': options},
  );

  /// Deletes a field definition and all its values (admin only).
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/custom-fields/$id');

  /// A task's field values, keyed by field id.
  Future<Map<int, String>> taskValues(int taskId) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/tasks/$taskId/fields',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return <int, String>{
      for (final dynamic e in data)
        (e as Map<String, dynamic>)['field_id'] as int:
            e['value'] as String? ?? '',
    };
  }

  /// Sets (or clears, when [value] is empty) one custom-field value on a task.
  Future<void> setTaskValue(int taskId, int fieldId, String value) =>
      _dio.put<void>(
        '/api/v1/tasks/$taskId/fields/$fieldId',
        data: <String, dynamic>{'value': value},
      );
}
