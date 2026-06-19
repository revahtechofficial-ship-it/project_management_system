import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/task.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../providers/dio_provider.dart';

/// The tasks repository, built from the shared Dio client. Feature-scoped
/// (AGENTS.md §1 `features/[feature]/providers`).
final Provider<TasksRepository> tasksRepositoryProvider =
    Provider<TasksRepository>((ref) {
      return TasksRepository(ref.watch(dioProvider));
    });

/// The list of tasks from the backend. Invalidate to refresh.
final FutureProvider<List<Task>> tasksProvider = FutureProvider<List<Task>>((
  ref,
) {
  return ref.watch(tasksRepositoryProvider).list();
});
