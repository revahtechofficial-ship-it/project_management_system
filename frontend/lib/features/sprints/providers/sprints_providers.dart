import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/sprint.dart';
import '../../../data/repositories/sprints_repository.dart';
import '../../../providers/dio_provider.dart';

/// The sprints repository, from the shared Dio client (AGENTS.md §1).
final Provider<SprintsRepository> sprintsRepositoryProvider =
    Provider<SprintsRepository>((ref) {
      return SprintsRepository(ref.watch(dioProvider));
    });

/// All sprints with rolled-up counts. Invalidate to refresh.
final FutureProvider<List<Sprint>> sprintsProvider =
    FutureProvider<List<Sprint>>((ref) {
      return ref.watch(sprintsRepositoryProvider).list();
    });
