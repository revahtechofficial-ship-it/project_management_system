import 'package:dio/dio.dart';

import '../models/cycle_metrics.dart';

/// Talks to /api/v1/metrics — delivery analytics (AGENTS.md §1
/// `data/repositories`).
class MetricsRepository {
  const MetricsRepository(this._dio);

  final Dio _dio;

  /// Cycle/lead-time metrics over completed tasks in the last [days] days.
  Future<CycleMetrics> cycleTime({int days = 90}) async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>(
          '/api/v1/metrics/cycle-time',
          queryParameters: <String, dynamic>{'days': days},
        );
    return CycleMetrics.fromJson(res.data ?? <String, dynamic>{});
  }
}
