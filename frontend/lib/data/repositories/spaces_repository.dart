import 'package:dio/dio.dart';

import '../models/folder.dart';
import '../models/space.dart';

/// Talks to /api/v1/spaces (and the nested /folders) — the project hierarchy.
/// Reads are open; writes are admin-only on the server.
class SpacesRepository {
  const SpacesRepository(this._dio);

  final Dio _dio;

  Future<List<Space>> listSpaces() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/spaces',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Space.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Space> createSpace({
    required String name,
    required String color,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/spaces',
          data: <String, dynamic>{'name': name, 'color': color},
        );
    return Space.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<void> updateSpace(
    int id, {
    required String name,
    required String color,
  }) => _dio.put<void>(
    '/api/v1/spaces/$id',
    data: <String, dynamic>{'name': name, 'color': color},
  );

  Future<void> deleteSpace(int id) => _dio.delete<void>('/api/v1/spaces/$id');

  Future<List<Folder>> listFolders() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/spaces/folders',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Folder.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Folder> createFolder({
    required int spaceId,
    required String name,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/spaces/folders',
          data: <String, dynamic>{'space_id': spaceId, 'name': name},
        );
    return Folder.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<void> updateFolder(int id, {required String name}) => _dio.put<void>(
    '/api/v1/spaces/folders/$id',
    data: <String, dynamic>{'name': name},
  );

  Future<void> deleteFolder(int id) =>
      _dio.delete<void>('/api/v1/spaces/folders/$id');
}
