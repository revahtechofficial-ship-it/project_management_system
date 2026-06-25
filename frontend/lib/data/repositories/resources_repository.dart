import 'package:dio/dio.dart';

import '../enums/availability_kind.dart';
import '../models/availability_entry.dart';
import '../models/member_capacity.dart';

/// Talks to /api/v1/resources — Resource Management: per-member weekly capacity
/// and availability/time off (AGENTS.md §1 `data/repositories`).
class ResourcesRepository {
  const ResourcesRepository(this._dio);

  final Dio _dio;

  Future<List<MemberCapacity>> capacity() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/resources/capacity',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => MemberCapacity.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> setCapacity(int userId, int weeklyHours) => _dio.put<void>(
    '/api/v1/resources/capacity/$userId',
    data: <String, dynamic>{'weekly_hours': weeklyHours},
  );

  Future<List<AvailabilityEntry>> availability() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/resources/availability',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map(
          (dynamic e) => AvailabilityEntry.fromJson(e as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> addAvailability({
    required int userId,
    required DateTime start,
    required DateTime end,
    required AvailabilityKind kind,
    String note = '',
  }) => _dio.post<void>(
    '/api/v1/resources/availability',
    data: <String, dynamic>{
      'user_id': userId,
      'start_date': _date(start),
      'end_date': _date(end),
      'kind': kind.toJson(),
      'note': note,
    },
  );

  Future<void> deleteAvailability(int id) =>
      _dio.delete<void>('/api/v1/resources/availability/$id');

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
