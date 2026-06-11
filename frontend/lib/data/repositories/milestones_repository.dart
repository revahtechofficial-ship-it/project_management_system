import 'package:dio/dio.dart';

import '../../core/utils/date_format.dart';
import '../models/milestone.dart';

/// Talks to the backend's /api/v1/milestones endpoints (AGENTS.md §1
/// `data/repositories`).
class MilestonesRepository {
  const MilestonesRepository(this._dio);

  final Dio _dio;

  /// Fetches all milestones, earliest due first.
  Future<List<Milestone>> list() async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/milestones');
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Milestone.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Creates a milestone. [dueDate] is sent as `YYYY-MM-DD`.
  Future<void> create({
    required String name,
    required DateTime dueDate,
    int? projectId,
  }) =>
      _dio.post<Map<String, dynamic>>(
        '/api/v1/milestones',
        data: <String, dynamic>{
          'name': name,
          'due_date': dateParam(dueDate),
          'project_id': projectId,
        },
      );

  /// Updates a milestone's name, date and done state.
  Future<void> update(
    int id, {
    required String name,
    required DateTime dueDate,
    required bool done,
  }) =>
      _dio.patch<Map<String, dynamic>>(
        '/api/v1/milestones/$id',
        data: <String, dynamic>{
          'name': name,
          'due_date': dateParam(dueDate),
          'done': done,
        },
      );

  /// Deletes the milestone identified by [id].
  Future<void> delete(int id) =>
      _dio.delete<void>('/api/v1/milestones/$id');
}
