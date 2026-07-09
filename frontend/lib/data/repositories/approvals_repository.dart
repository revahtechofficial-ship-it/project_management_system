import 'package:dio/dio.dart';

import '../models/approval.dart';

/// Talks to the backend's /api/v1/approvals endpoints (AGENTS.md §1
/// `data/repositories`).
class ApprovalsRepository {
  const ApprovalsRepository(this._dio);

  final Dio _dio;

  List<Approval> _parse(Response<List<dynamic>> res) => <Approval>[
    for (final dynamic e in res.data ?? <dynamic>[])
      Approval.fromJson(e as Map<String, dynamic>),
  ];

  /// Approvals awaiting the current user's decision.
  Future<List<Approval>> pending() async =>
      _parse(await _dio.get<List<dynamic>>('/api/v1/approvals/pending'));

  /// Approval requests the current user has made.
  Future<List<Approval>> mine() async =>
      _parse(await _dio.get<List<dynamic>>('/api/v1/approvals/mine'));

  /// Approvals recorded against one subject (e.g. a task).
  Future<List<Approval>> forSubject(String type, int id) async => _parse(
    await _dio.get<List<dynamic>>(
      '/api/v1/approvals/subject',
      queryParameters: <String, dynamic>{'type': type, 'id': id},
    ),
  );

  /// Requests sign-off on a subject from [approverId].
  Future<void> request({
    required String subjectType,
    required int subjectId,
    required String subjectTitle,
    required int approverId,
    String note = '',
  }) => _dio.post<void>(
    '/api/v1/approvals',
    data: <String, dynamic>{
      'subject_type': subjectType,
      'subject_id': subjectId,
      'subject_title': subjectTitle,
      'approver_id': approverId,
      'note': note,
    },
  );

  /// Approves or rejects an approval (approver-only server-side).
  Future<void> decide(int id, {required bool approved}) => _dio.post<void>(
    '/api/v1/approvals/$id/decide',
    data: <String, dynamic>{'status': approved ? 'approved' : 'rejected'},
  );
}
