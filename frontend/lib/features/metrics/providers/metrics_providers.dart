import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/cycle_metrics.dart';
import '../../../data/repositories/metrics_repository.dart';
import '../../../providers/dio_provider.dart';

/// The metrics repository, from the shared Dio client (AGENTS.md §1).
final Provider<MetricsRepository> metricsRepositoryProvider =
    Provider<MetricsRepository>((ref) {
  return MetricsRepository(ref.watch(dioProvider));
});

/// Cycle/lead-time metrics over the last N days, keyed by the window.
final cycleMetricsProvider =
    FutureProvider.family<CycleMetrics, int>((ref, int days) {
  return ref.watch(metricsRepositoryProvider).cycleTime(days: days);
});
