import 'package:dio/dio.dart';

import '../models/release.dart';

/// Talks to /api/v1/releases — release planning (AGENTS.md §1).
class ReleasesRepository {
  const ReleasesRepository(this._dio);

  final Dio _dio;

  Future<List<Release>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/releases',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Release.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Map<String, dynamic> _body(Release r) => <String, dynamic>{
    'name': r.name,
    'version': r.version,
    'status': r.status.toJson(),
    'target_date': r.toJson()['target_date'],
    'notes': r.notes,
  };

  Future<void> create(Release release) =>
      _dio.post<void>('/api/v1/releases', data: _body(release));

  Future<void> update(int id, Release release) =>
      _dio.put<void>('/api/v1/releases/$id', data: _body(release));

  Future<void> delete(int id) => _dio.delete<void>('/api/v1/releases/$id');
}
