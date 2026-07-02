import 'package:dio/dio.dart';

import '../models/one_on_one.dart';

/// A 1:1 meeting with its items, as returned by `GET /one-on-ones/{id}`.
typedef OneOnOneDetail = ({OneOnOne meeting, List<OneOnOneItem> items});

/// Talks to the backend's /api/v1/one-on-ones endpoints (AGENTS.md §1
/// `data/repositories`).
class OneOnOnesRepository {
  const OneOnOnesRepository(this._dio);

  final Dio _dio;

  /// The current user's 1:1s (as manager or report), newest first.
  Future<List<OneOnOne>> list() async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/one-on-ones');
    return <OneOnOne>[
      for (final dynamic e in res.data ?? <dynamic>[])
        OneOnOne.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Schedules a new 1:1 with [reportId] at [scheduledAt].
  Future<OneOnOne> create({
    required int reportId,
    required DateTime scheduledAt,
  }) async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      '/api/v1/one-on-ones',
      data: <String, dynamic>{
        'report_id': reportId,
        'scheduled_at': scheduledAt.toIso8601String(),
      },
    );
    return OneOnOne.fromJson(res.data ?? <String, dynamic>{});
  }

  /// A single 1:1 with its agenda/notes/action items.
  Future<OneOnOneDetail> get(int id) async {
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>('/api/v1/one-on-ones/$id');
    final Map<String, dynamic> data = res.data ?? <String, dynamic>{};
    return (
      meeting: OneOnOne.fromJson(data),
      items: <OneOnOneItem>[
        for (final dynamic e in data['items'] as List<dynamic>? ?? <dynamic>[])
          OneOnOneItem.fromJson(e as Map<String, dynamic>),
      ],
    );
  }

  Future<void> reschedule(int id, DateTime at) => _dio.patch<void>(
        '/api/v1/one-on-ones/$id',
        data: <String, dynamic>{'scheduled_at': at.toIso8601String()},
      );

  Future<void> delete(int id) =>
      _dio.delete<void>('/api/v1/one-on-ones/$id');

  Future<void> addItem(int meetingId, String kind, String body) =>
      _dio.post<void>(
        '/api/v1/one-on-ones/$meetingId/items',
        data: <String, dynamic>{'kind': kind, 'body': body},
      );

  Future<void> setItemDone(int itemId, bool done) => _dio.patch<void>(
        '/api/v1/one-on-ones/items/$itemId',
        data: <String, dynamic>{'done': done},
      );

  Future<void> deleteItem(int itemId) =>
      _dio.delete<void>('/api/v1/one-on-ones/items/$itemId');
}
