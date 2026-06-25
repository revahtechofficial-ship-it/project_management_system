import 'package:dio/dio.dart';

import '../models/feed_activity.dart';

/// Talks to /api/v1/activity — the workspace collaboration history feed
/// (AGENTS.md §1 `data/repositories`).
class ActivityRepository {
  const ActivityRepository(this._dio);

  final Dio _dio;

  /// The most recent workspace activity, newest first.
  Future<List<FeedActivity>> recent() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/activity',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => FeedActivity.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
