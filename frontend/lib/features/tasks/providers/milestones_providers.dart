import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/milestone.dart';
import '../../../data/repositories/milestones_repository.dart';
import '../../../providers/dio_provider.dart';

/// The milestones repository, built from the shared Dio client (AGENTS.md §1).
final Provider<MilestonesRepository> milestonesRepositoryProvider =
    Provider<MilestonesRepository>((ref) {
  return MilestonesRepository(ref.watch(dioProvider));
});

/// All workspace milestones, earliest due first. Invalidate to refresh.
final FutureProvider<List<Milestone>> milestonesProvider =
    FutureProvider<List<Milestone>>((ref) {
  return ref.watch(milestonesRepositoryProvider).list();
});
