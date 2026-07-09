import 'package:dio/dio.dart';

import '../models/saved_filter.dart';

/// Talks to /api/v1/saved-filters — named, reusable task filters
/// (AGENTS.md §1 `data/repositories`).
class SavedFiltersRepository {
  const SavedFiltersRepository(this._dio);

  final Dio _dio;

  Future<List<SavedFilter>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/saved-filters',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => SavedFilter.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> create(String name, Map<String, dynamic> config) =>
      _dio.post<void>(
        '/api/v1/saved-filters',
        data: <String, dynamic>{'name': name, 'config': config},
      );

  Future<void> delete(int id) => _dio.delete<void>('/api/v1/saved-filters/$id');
}
