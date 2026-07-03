import 'package:dio/dio.dart';

import '../../core/utils/date_format.dart';
import '../models/expense.dart';

/// Talks to the backend's /api/v1/expenses endpoints (AGENTS.md §1
/// `data/repositories`).
class ExpensesRepository {
  const ExpensesRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _body(Expense e) => <String, dynamic>{
        'project_id': e.projectId,
        'category': e.category.toJson(),
        'amount_cents': e.amountCents,
        'spent_on': dateParam(e.spentOn) ?? '',
        'description': e.description,
        'merchant': e.merchant,
        'receipt_url': e.receiptUrl,
      };

  /// Every expense claim, newest spend first.
  Future<List<Expense>> list() async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/expenses');
    return <Expense>[
      for (final dynamic e in res.data ?? <dynamic>[])
        Expense.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Files a new expense claim (submitter is the current user, server-side).
  Future<void> create(Expense e) =>
      _dio.post<void>('/api/v1/expenses', data: _body(e));

  /// Saves edits to an existing claim.
  Future<void> update(int id, Expense e) =>
      _dio.patch<void>('/api/v1/expenses/$id', data: _body(e));

  /// Moves a claim through the approve / reject / reimburse workflow.
  Future<void> setStatus(int id, String status) => _dio.patch<void>(
        '/api/v1/expenses/$id/status',
        data: <String, dynamic>{'status': status},
      );

  /// Removes a claim.
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/expenses/$id');
}
