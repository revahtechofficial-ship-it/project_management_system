import 'package:dio/dio.dart';

import '../../core/utils/date_format.dart';
import '../models/calendar_entry.dart';

/// Talks to /api/v1/events — the caller's own calendar entries
/// (AGENTS.md §1 `data/repositories`).
class CalendarEntriesRepository {
  const CalendarEntriesRepository(this._dio);

  final Dio _dio;

  /// The caller's entries. Repeating ones come back whatever window is asked
  /// for, since a birthday recorded in 1994 still belongs on this year's grid.
  Future<List<CalendarEntry>> list({DateTime? from, DateTime? to}) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/events',
      queryParameters: <String, dynamic>{
        if (from != null) 'from': dateParam(from),
        if (to != null) 'to': dateParam(to),
      },
    );
    return <CalendarEntry>[
      for (final dynamic e in res.data ?? <dynamic>[])
        CalendarEntry.fromJson(e as Map<String, dynamic>),
    ];
  }

  Future<void> create(CalendarEntry entry) =>
      _dio.post<void>('/api/v1/events', data: entry.toJson());

  Future<void> update(CalendarEntry entry) =>
      _dio.put<void>('/api/v1/events/${entry.id}', data: entry.toJson());

  Future<void> delete(int id) => _dio.delete<void>('/api/v1/events/$id');
}
