import 'package:dio/dio.dart';

import '../models/activity.dart';
import '../models/comment.dart';

/// Talks to a task's comment + activity endpoints (AGENTS.md §1
/// `data/repositories`).
class CommentsRepository {
  const CommentsRepository(this._dio);

  final Dio _dio;

  /// Comments on a task, oldest first.
  Future<List<Comment>> list(int taskId) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/tasks/$taskId/comments',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Posts a comment. [mentions] are the ids of mentioned members; pass
  /// [parentId] to post a threaded reply to another comment.
  Future<void> add(
    int taskId,
    String body,
    List<int> mentions, {
    int? parentId,
  }) => _dio.post<Map<String, dynamic>>(
    '/api/v1/tasks/$taskId/comments',
    data: <String, dynamic>{
      'body': body,
      'mentions': mentions,
      'parent_id': ?parentId,
    },
  );

  /// Deletes a comment (author or admin on the server).
  Future<void> delete(int commentId) =>
      _dio.delete<void>('/api/v1/tasks/comments/$commentId');

  /// The recent activity timeline for a task, newest first.
  Future<List<Activity>> listActivity(int taskId) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/tasks/$taskId/activity',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Activity.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
