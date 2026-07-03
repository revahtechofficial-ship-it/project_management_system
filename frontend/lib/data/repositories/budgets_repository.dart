import 'package:dio/dio.dart';

import '../models/budget.dart';

/// Talks to the backend's /api/v1/budgets endpoints (AGENTS.md §1
/// `data/repositories`).
class BudgetsRepository {
  const BudgetsRepository(this._dio);

  final Dio _dio;

  /// Every project budget with its rolled-up actual cost.
  Future<List<Budget>> list() async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/budgets');
    return <Budget>[
      for (final dynamic e in res.data ?? <dynamic>[])
        Budget.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Sets or updates the budget for a project (keyed by project, server-side).
  Future<void> upsert({
    required int projectId,
    required int amountCents,
    required int hourlyRateCents,
    String notes = '',
  }) =>
      _dio.put<void>(
        '/api/v1/budgets',
        data: <String, dynamic>{
          'project_id': projectId,
          'amount_cents': amountCents,
          'hourly_rate_cents': hourlyRateCents,
          'notes': notes,
        },
      );

  /// Removes a project budget.
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/budgets/$id');
}
