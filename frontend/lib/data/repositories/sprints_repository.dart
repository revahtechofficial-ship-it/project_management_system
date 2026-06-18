import 'package:dio/dio.dart';

import '../../core/utils/date_format.dart';
import '../enums/sprint_status.dart';
import '../models/sprint.dart';

/// Talks to /api/v1/sprints — time-boxed iterations of tasks.
class SprintsRepository {
  const SprintsRepository(this._dio);

  final Dio _dio;

  /// All sprints, newest first, with rolled-up task/point counts.
  Future<List<Sprint>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/sprints',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Sprint.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Creates a sprint.
  Future<Sprint> create({
    required String name,
    String goal = '',
    SprintStatus status = SprintStatus.planned,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/sprints',
          data: <String, dynamic>{
            'name': name,
            'goal': goal,
            'status': status.toJson(),
            'start_date': dateParam(startDate),
            'end_date': dateParam(endDate),
          },
        );
    return Sprint.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Updates a sprint's name, goal and dates.
  Future<void> update(
    int id, {
    required String name,
    String goal = '',
    DateTime? startDate,
    DateTime? endDate,
  }) => _dio.put<void>(
    '/api/v1/sprints/$id',
    data: <String, dynamic>{
      'name': name,
      'goal': goal,
      'start_date': dateParam(startDate),
      'end_date': dateParam(endDate),
    },
  );

  /// Marks a sprint active.
  Future<void> start(int id) => _dio.post<void>('/api/v1/sprints/$id/start');

  /// Marks a sprint complete; unfinished tasks return to the backlog.
  Future<void> complete(int id) =>
      _dio.post<void>('/api/v1/sprints/$id/complete');

  /// Deletes a sprint (its tasks return to the backlog).
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/sprints/$id');
}
