import 'package:dio/dio.dart';

import '../models/time_entry.dart';

/// Talks to /api/v1/time-entries — the timer and time log (AGENTS.md §1).
class TimeEntriesRepository {
  const TimeEntriesRepository(this._dio);

  final Dio _dio;

  /// The current user's entries, newest first (optionally within a date range).
  Future<List<TimeEntry>> list({String? from, String? to}) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/time-entries',
      queryParameters: <String, dynamic>{'from': ?from, 'to': ?to},
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => TimeEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// The currently running timer, or null when nothing is running.
  Future<TimeEntry?> active() async {
    final Response<dynamic> res = await _dio.get<dynamic>(
      '/api/v1/time-entries/active',
    );
    final dynamic data = res.data;
    if (data == null || data is! Map) {
      return null;
    }
    return TimeEntry.fromJson(Map<String, dynamic>.from(data));
  }

  /// Starts a timer (stopping any already running) and returns it.
  Future<TimeEntry> start({
    int? taskId,
    String description = '',
    bool billable = false,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/time-entries/start',
          data: <String, dynamic>{
            'task_id': taskId,
            'description': description,
            'billable': billable,
          },
        );
    return TimeEntry.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Stops a running timer and returns the completed entry.
  Future<TimeEntry> stop(int id) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>('/api/v1/time-entries/$id/stop');
    return TimeEntry.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Logs a manual entry of [minutes] on [date] (YYYY-MM-DD).
  Future<TimeEntry> create({
    int? taskId,
    required int minutes,
    required String date,
    String description = '',
    bool billable = false,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/time-entries',
          data: <String, dynamic>{
            'task_id': taskId,
            'minutes': minutes,
            'date': date,
            'description': description,
            'billable': billable,
          },
        );
    return TimeEntry.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<void> update(
    int id, {
    int? taskId,
    required int minutes,
    required String date,
    String description = '',
    bool billable = false,
  }) => _dio.patch<void>(
    '/api/v1/time-entries/$id',
    data: <String, dynamic>{
      'task_id': taskId,
      'minutes': minutes,
      'date': date,
      'description': description,
      'billable': billable,
    },
  );

  Future<void> delete(int id) => _dio.delete<void>('/api/v1/time-entries/$id');
}
