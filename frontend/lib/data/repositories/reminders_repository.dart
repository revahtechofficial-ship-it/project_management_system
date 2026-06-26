import 'package:dio/dio.dart';

import '../models/reminder.dart';

/// Talks to /api/v1/reminders — user-set reminders (AGENTS.md §1).
class RemindersRepository {
  const RemindersRepository(this._dio);

  final Dio _dio;

  Future<List<Reminder>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/reminders',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Reminder.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> create({
    required DateTime remindAt,
    String note = '',
    int? taskId,
  }) => _dio.post<void>(
    '/api/v1/reminders',
    data: <String, dynamic>{
      'remind_at': remindAt.toUtc().toIso8601String(),
      'note': note,
      'task_id': taskId,
    },
  );

  Future<void> delete(int id) => _dio.delete<void>('/api/v1/reminders/$id');
}
