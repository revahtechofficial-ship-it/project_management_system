import 'package:dio/dio.dart';

import '../models/favorite.dart';

/// Talks to /api/v1/favorites — starred tasks, projects and pages
/// (AGENTS.md §1 `data/repositories`).
class FavoritesRepository {
  const FavoritesRepository(this._dio);

  final Dio _dio;

  Future<List<Favorite>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/favorites',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Favorite.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> add({
    required String kind,
    required int itemId,
    required String label,
    required String route,
  }) => _dio.post<void>(
    '/api/v1/favorites',
    data: <String, dynamic>{
      'kind': kind,
      'item_id': itemId,
      'label': label,
      'route': route,
    },
  );

  Future<void> remove(String kind, int itemId) =>
      _dio.delete<void>('/api/v1/favorites/$kind/$itemId');
}
