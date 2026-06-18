import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/workflow_status.dart';
import '../../../data/repositories/statuses_repository.dart';
import '../../../providers/dio_provider.dart';

/// The statuses repository, from the shared Dio client (AGENTS.md §1).
final Provider<StatusesRepository> statusesRepositoryProvider =
    Provider<StatusesRepository>((ref) {
      return StatusesRepository(ref.watch(dioProvider));
    });

/// The workspace's task workflow statuses (board columns), ordered by
/// position. Invalidate to refresh after an edit.
final FutureProvider<List<WorkflowStatus>> statusesProvider =
    FutureProvider<List<WorkflowStatus>>((ref) {
      return ref.watch(statusesRepositoryProvider).list();
    });
