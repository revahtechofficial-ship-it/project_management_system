import 'package:dio/dio.dart';

/// Talks to /api/v1/calendar — the per-user calendar feed token (AGENTS.md §1
/// `data/repositories`).
class CalendarRepository {
  const CalendarRepository(this._dio);

  final Dio _dio;

  /// The current feed token, or an empty string when no feed is enabled.
  Future<String> token() async {
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>('/api/v1/calendar');
    return res.data?['token'] as String? ?? '';
  }

  /// Generates (or rotates) the feed token and returns the new one.
  Future<String> rotate() async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>('/api/v1/calendar');
    return res.data?['token'] as String? ?? '';
  }

  /// Disables the feed (revokes the token).
  Future<void> revoke() => _dio.delete<void>('/api/v1/calendar');
}
