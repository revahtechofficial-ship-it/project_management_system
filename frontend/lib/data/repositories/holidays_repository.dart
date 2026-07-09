import 'package:dio/dio.dart';

import '../../core/utils/date_format.dart';
import '../models/holiday.dart';

/// Talks to /api/v1/holidays — the calendar's holidays (AGENTS.md §1
/// `data/repositories`).
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

  /// Adds a holiday (admin only, enforced server-side).
  Future<void> create({
    required DateTime date,
    required String nameEn,
    String nameNe = '',
    bool isPublic = true,
  }) => _dio.post<void>(
    '/api/v1/holidays',
    data: <String, dynamic>{
      'date': dateParam(date),
      'name_en': nameEn,
      'name_ne': nameNe,
      'is_public': isPublic,
    },
  );

  /// Removes a holiday (admin only).
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/holidays/$id');
}
