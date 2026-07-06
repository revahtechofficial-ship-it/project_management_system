import 'package:dio/dio.dart';

import '../enums/page_type.dart';
import '../models/form_response_entry.dart';
import '../models/page_backlink.dart';
import '../models/page_share.dart';
import '../models/page_version.dart';
import '../models/workspace_page.dart';

/// Talks to /api/v1/pages — the Docs / Whiteboard / Form workspace pages
/// (AGENTS.md §1 `data/repositories`).
class PagesRepository {
  const PagesRepository(this._dio);

  final Dio _dio;

  /// Lists pages of a given [type] (no bodies). Set [templates] true to list the
  /// reusable templates of that type instead of real pages.
  Future<List<WorkspacePage>> list(
    PageType type, {
    bool templates = false,
  }) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/pages',
      queryParameters: <String, dynamic>{
        'type': type.toJson(),
        if (templates) 'template': 'true',
      },
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

  /// Creates a page of [type], optionally nested under [parentId]; returns the
  /// stored record. Set [isTemplate] to save it as a reusable template.
  Future<WorkspacePage> create({
    required PageType type,
    String title = '',
    String body = '',
    String icon = '',
    int? parentId,
    bool isTemplate = false,
    String category = '',
    int? ownerId,
    String? reviewAt,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/pages',
          data: <String, dynamic>{
            'type': type.toJson(),
            'title': title,
            'body': body,
            'icon': icon,
            'parent_id': parentId,
            'is_template': isTemplate,
            'category': category,
            'owner_id': ownerId,
            'review_at': reviewAt,
          },
        );
    return WorkspacePage.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Re-parents a page (pass `null` to move it to the top level).
  Future<void> setParent(int id, int? parentId) => _dio.patch<void>(
    '/api/v1/pages/$id/parent',
    data: <String, dynamic>{'parent_id': parentId},
  );

  /// Saves a page's title, body, icon and SOP metadata; returns the updated
  /// record.
  Future<WorkspacePage> update(
    int id, {
    required String title,
    required String body,
    String icon = '',
    String category = '',
    int? ownerId,
    String? reviewAt,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .put<Map<String, dynamic>>(
          '/api/v1/pages/$id',
          data: <String, dynamic>{
            'title': title,
            'body': body,
            'icon': icon,
            'category': category,
            'owner_id': ownerId,
            'review_at': reviewAt,
          },
        );
    return WorkspacePage.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Deletes a page (its author or an admin only, enforced server-side).
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/pages/$id');

  /// Lists a page's saved revisions, newest first.
  Future<List<PageVersion>> versions(int id) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/pages/$id/versions',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => PageVersion.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Restores a page to an earlier revision (the current content is snapshotted
  /// first, so the restore can itself be undone).
  Future<void> restoreVersion(int id, int versionId) => _dio.post<void>(
        '/api/v1/pages/$id/versions/$versionId/restore',
      );

  /// Lists the pages that link to this page via `[[wiki links]]`.
  Future<List<PageBacklink>> backlinks(int id) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/pages/$id/backlinks',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => PageBacklink.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Sets a page's visibility: `'workspace'` (everyone) or `'private'`.
  Future<void> setVisibility(int id, String visibility) => _dio.patch<void>(
    '/api/v1/pages/$id/visibility',
    data: <String, dynamic>{'visibility': visibility},
  );

  /// Lists the users a (private) page is shared with.
  Future<List<PageShare>> shares(int id) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/pages/$id/shares',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => PageShare.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Shares a page with a user at `'view'` or `'edit'` permission (upsert).
  Future<void> addShare(int id, int userId, String permission) =>
      _dio.post<void>(
        '/api/v1/pages/$id/shares',
        data: <String, dynamic>{'user_id': userId, 'permission': permission},
      );

  /// Revokes a user's access to a shared page.
  Future<void> removeShare(int id, int userId) =>
      _dio.delete<void>('/api/v1/pages/$id/shares/$userId');

  /// Submits a response to a form page (any user with access).
  Future<void> submitForm(int id, Map<String, dynamic> answers) =>
      _dio.post<void>(
        '/api/v1/pages/$id/responses',
        data: <String, dynamic>{'answers': answers},
      );

  /// Lists a form's responses (owner/admin only).
  Future<List<FormResponseEntry>> formResponses(int id) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/pages/$id/responses',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map(
          (dynamic e) => FormResponseEntry.fromJson(e as Map<String, dynamic>),
        )
        .toList(growable: false);
  }
}
