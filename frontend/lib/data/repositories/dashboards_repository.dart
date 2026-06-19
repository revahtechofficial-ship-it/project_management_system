import 'package:dio/dio.dart';

import '../models/saved_dashboard.dart';

/// Talks to /api/v1/dashboards — saved, shareable dashboards (AGENTS.md §1).
class DashboardsRepository {
  const DashboardsRepository(this._dio);

  final Dio _dio;

  /// Dashboards visible to the current user (workspace ones + their own).
  Future<List<SavedDashboard>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/dashboards',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => SavedDashboard.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<SavedDashboard> get(int id) async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/dashboards/$id');
    return SavedDashboard.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<SavedDashboard> create({
    required String name,
    required String visibility,
    required List<String> widgets,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/dashboards',
          data: <String, dynamic>{
            'name': name,
            'visibility': visibility,
            'widgets': widgets,
          },
        );
    return SavedDashboard.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<void> update(
    int id, {
    required String name,
    required String visibility,
    required List<String> widgets,
  }) => _dio.put<void>(
    '/api/v1/dashboards/$id',
    data: <String, dynamic>{
      'name': name,
      'visibility': visibility,
      'widgets': widgets,
    },
  );

  Future<void> delete(int id) => _dio.delete<void>('/api/v1/dashboards/$id');
}
