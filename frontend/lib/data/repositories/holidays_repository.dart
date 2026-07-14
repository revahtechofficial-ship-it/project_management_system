import 'package:dio/dio.dart';

import '../../core/utils/date_format.dart';
import '../models/holiday.dart';

/// Talks to /api/v1/holidays — the calendar's holidays and festivals
/// (AGENTS.md §1 `data/repositories`).
class HolidaysRepository {
  const HolidaysRepository(this._dio);

  final Dio _dio;

  /// Holidays between [from] and [to]; the server defaults to a wide window
  /// around today when both are omitted.
  Future<List<Holiday>> list({DateTime? from, DateTime? to}) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/holidays',
      queryParameters: <String, dynamic>{
        if (from != null) 'from': dateParam(from),
        if (to != null) 'to': dateParam(to),
      },
    );
    return <Holiday>[
      for (final dynamic e in res.data ?? <dynamic>[])
        Holiday.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Adds [holiday], ignoring its id (admin only, enforced server-side).
  ///
  /// The server upserts on (date, name), so re-adding an existing festival
  /// rewrites its prose rather than failing.
  Future<void> create(Holiday holiday) =>
      _dio.post<void>('/api/v1/holidays', data: holiday.toJson());

  /// Rewrites the holiday carrying [Holiday.id] (admin only).
  Future<void> update(Holiday holiday) =>
      _dio.put<void>('/api/v1/holidays/${holiday.id}', data: holiday.toJson());

  /// Removes a holiday (admin only).
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/holidays/$id');

  /// The caller's own notice period for public holidays, or null for none.
  Future<int?> reminderDays() async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/holidays/reminder');
    return res.data?['remind_days'] as int?;
  }

  /// Sets it. Null turns holiday reminders off.
  Future<void> setReminderDays(int? days) => _dio.put<void>(
    '/api/v1/holidays/reminder',
    data: <String, dynamic>{'remind_days': days},
  );
}
