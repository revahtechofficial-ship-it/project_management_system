import 'package:dio/dio.dart';

import '../models/timesheet_submission.dart';

/// Talks to the backend's /api/v1/timesheets endpoints (AGENTS.md §1
/// `data/repositories`).
class TimesheetsRepository {
  const TimesheetsRepository(this._dio);

  final Dio _dio;

  /// Submits (or re-submits) the timesheet for the week containing
  /// [weekStart]; the backend snaps to that week's Monday and totals the time.
  Future<TimesheetSubmission> submit(
    DateTime weekStart, {
    String note = '',
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/timesheets',
          data: <String, dynamic>{
            'week_start': weekStart.toIso8601String(),
            'note': note,
          },
        );
    return TimesheetSubmission.fromJson(res.data ?? <String, dynamic>{});
  }

  /// The current user's recent timesheet submissions.
  Future<List<TimesheetSubmission>> listMine() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/timesheets',
    );
    return <TimesheetSubmission>[
      for (final dynamic e in res.data ?? <dynamic>[])
        TimesheetSubmission.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Pending submissions awaiting approval (admin-only server-side).
  Future<List<TimesheetSubmission>> pending() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/timesheets/pending',
    );
    return <TimesheetSubmission>[
      for (final dynamic e in res.data ?? <dynamic>[])
        TimesheetSubmission.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Approves or rejects a submission (admin-only server-side).
  Future<void> decide(int id, {required bool approved}) {
    return _dio.post<void>(
      '/api/v1/timesheets/$id/decide',
      data: <String, dynamic>{'status': approved ? 'approved' : 'rejected'},
    );
  }
}
