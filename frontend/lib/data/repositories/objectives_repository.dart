import 'package:dio/dio.dart';

import '../models/objective.dart';

/// Talks to /api/v1/objectives — Goals & OKRs (AGENTS.md §1).
class ObjectivesRepository {
  const ObjectivesRepository(this._dio);

  final Dio _dio;

  /// All objectives, each with its key results and computed progress.
  Future<List<Objective>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/objectives',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Objective.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> create({
    required String title,
    String description = '',
    int? ownerId,
    int? parentId,
    String period = '',
    String status = 'active',
  }) => _dio.post<void>(
    '/api/v1/objectives',
    data: <String, dynamic>{
      'title': title,
      'description': description,
      'owner_id': ownerId,
      'parent_id': parentId,
      'period': period,
      'status': status,
    },
  );

  Future<void> update(
    int id, {
    required String title,
    String description = '',
    int? ownerId,
    int? parentId,
    String period = '',
    String status = 'active',
  }) => _dio.put<void>(
    '/api/v1/objectives/$id',
    data: <String, dynamic>{
      'title': title,
      'description': description,
      'owner_id': ownerId,
      'parent_id': parentId,
      'period': period,
      'status': status,
    },
  );

  Future<void> delete(int id) => _dio.delete<void>('/api/v1/objectives/$id');

  Future<void> addKeyResult(
    int objectiveId, {
    required String title,
    double startValue = 0,
    double currentValue = 0,
    double targetValue = 100,
    String unit = '',
  }) => _dio.post<void>(
    '/api/v1/objectives/$objectiveId/key-results',
    data: <String, dynamic>{
      'title': title,
      'start_value': startValue,
      'current_value': currentValue,
      'target_value': targetValue,
      'unit': unit,
    },
  );

  Future<void> updateKeyResult(
    int krId, {
    required String title,
    required double startValue,
    required double currentValue,
    required double targetValue,
    String unit = '',
  }) => _dio.patch<void>(
    '/api/v1/objectives/key-results/$krId',
    data: <String, dynamic>{
      'title': title,
      'start_value': startValue,
      'current_value': currentValue,
      'target_value': targetValue,
      'unit': unit,
    },
  );

  Future<void> deleteKeyResult(int krId) =>
      _dio.delete<void>('/api/v1/objectives/key-results/$krId');
}
