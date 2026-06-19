import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/saved_dashboard.dart';
import '../../../data/repositories/dashboards_repository.dart';
import '../../../providers/dio_provider.dart';

/// The dashboards repository, from the shared Dio client (AGENTS.md §1).
final Provider<DashboardsRepository> dashboardsRepositoryProvider =
    Provider<DashboardsRepository>((ref) {
      return DashboardsRepository(ref.watch(dioProvider));
    });

/// Saved dashboards visible to the current user. Invalidate to refresh.
final FutureProvider<List<SavedDashboard>> savedDashboardsProvider =
    FutureProvider<List<SavedDashboard>>((ref) {
      return ref.watch(dashboardsRepositoryProvider).list();
    });
