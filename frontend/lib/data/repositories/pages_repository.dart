import 'package:dio/dio.dart';

import '../enums/page_type.dart';
import '../models/workspace_page.dart';

/// Talks to /api/v1/pages — the Docs / Whiteboard / Form workspace pages
/// (AGENTS.md §1 `data/repositories`).
class PagesRepository {
  const PagesRepository(this._dio);

  final Dio _dio;

  /// Lists pages of a given [type], most-recently-updated first (no bodies).
  Future<List<WorkspacePage>> list(PageType type) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/pages',
      queryParameters: <String, dynamic>{'type': type.toJson()},
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => WorkspacePage.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Fetches a single page including its full body.
  Future<WorkspacePage> get(int id) async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/pages/$id');
    return WorkspacePage.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Creates a page of [type]; returns the stored record.
  Future<WorkspacePage> create({
    required PageType type,
    String title = '',
    String body = '',
    String icon = '',
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/pages',
          data: <String, dynamic>{
            'type': type.toJson(),
            'title': title,
            'body': body,
            'icon': icon,
          },
        );
    return WorkspacePage.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Saves a page's title, body and icon; returns the updated record.
  Future<WorkspacePage> update(
    int id, {
    required String title,
    required String body,
    String icon = '',
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .put<Map<String, dynamic>>(
          '/api/v1/pages/$id',
          data: <String, dynamic>{'title': title, 'body': body, 'icon': icon},
        );
    return WorkspacePage.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Deletes a page (its author or an admin only, enforced server-side).
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/pages/$id');
}
