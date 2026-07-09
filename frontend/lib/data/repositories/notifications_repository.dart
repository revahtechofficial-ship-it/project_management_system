import 'package:dio/dio.dart';

import '../models/app_notification.dart';

/// Talks to the backend's /api/v1/notifications endpoints (AGENTS.md §1
/// `data/repositories`).
class NotificationsRepository {
  const NotificationsRepository(this._dio);

  final Dio _dio;

  /// Fetches the most recent notifications (newest first).
  Future<List<AppNotification>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/notifications',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Returns the number of unread notifications.
  Future<int> unreadCount() async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/notifications/unread-count');
    return (res.data?['count'] as num?)?.toInt() ?? 0;
  }

  /// Marks a single notification read.
  Future<void> markRead(int id) =>
      _dio.patch<void>('/api/v1/notifications/$id/read');

  /// Marks every notification read.
  Future<void> markAllRead() =>
      _dio.post<void>('/api/v1/notifications/read-all');
}
