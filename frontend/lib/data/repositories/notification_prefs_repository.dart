import 'package:dio/dio.dart';

import '../models/notification_prefs.dart';

/// Talks to /api/v1/account/notification-prefs — per-category notification
/// channel preferences (AGENTS.md §1 `data/repositories`).
class NotificationPrefsRepository {
  const NotificationPrefsRepository(this._dio);

  final Dio _dio;

  /// The current user's notification preferences.
  Future<NotificationPrefs> get() async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/account/notification-prefs');
    return NotificationPrefs.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Saves the notification preferences.
  Future<void> set(NotificationPrefs prefs) => _dio.put<void>(
    '/api/v1/account/notification-prefs',
    data: prefs.toJson(),
  );
}
