import 'package:dio/dio.dart';

import '../enums/leave_type.dart';
import '../models/leave_request.dart';

/// A leave balance snapshot for the current year.
typedef LeaveBalance = ({int used, int allowance, int remaining});

/// Talks to the backend's /api/v1/leave endpoints (AGENTS.md §1
/// `data/repositories`).
class LeaveRepository {
  const LeaveRepository(this._dio);

  final Dio _dio;

  List<LeaveRequest> _parse(Response<List<dynamic>> res) => <LeaveRequest>[
        for (final dynamic e in res.data ?? <dynamic>[])
          LeaveRequest.fromJson(e as Map<String, dynamic>),
      ];

  /// The current user's leave requests.
  Future<List<LeaveRequest>> listMine() async =>
      _parse(await _dio.get<List<dynamic>>('/api/v1/leave'));

  /// The current user's vacation balance for the year.
  Future<LeaveBalance> balance() async {
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>('/api/v1/leave/balance');
    final Map<String, dynamic> d = res.data ?? <String, dynamic>{};
    return (
      used: d['used'] as int? ?? 0,
      allowance: d['allowance'] as int? ?? 0,
      remaining: d['remaining'] as int? ?? 0,
    );
  }

  /// Approved leave overlapping the coming weeks (who's out).
  Future<List<LeaveRequest>> calendar() async =>
      _parse(await _dio.get<List<dynamic>>('/api/v1/leave/calendar'));

  /// Pending requests awaiting approval (admin-only server-side).
  Future<List<LeaveRequest>> pending() async =>
      _parse(await _dio.get<List<dynamic>>('/api/v1/leave/pending'));

  /// Files a new leave request.
  Future<void> create({
    required LeaveType type,
    required DateTime start,
    required DateTime end,
    String note = '',
  }) =>
      _dio.post<void>(
        '/api/v1/leave',
        data: <String, dynamic>{
          'type': type.toJson(),
          'start_date': start.toIso8601String(),
          'end_date': end.toIso8601String(),
          'note': note,
        },
      );

  /// Approves or rejects a request (admin-only server-side).
  Future<void> decide(int id, {required bool approved}) => _dio.post<void>(
        '/api/v1/leave/$id/decide',
        data: <String, dynamic>{'status': approved ? 'approved' : 'rejected'},
      );

  /// Cancels one of the current user's pending requests.
  Future<void> cancel(int id) => _dio.delete<void>('/api/v1/leave/$id');
}
