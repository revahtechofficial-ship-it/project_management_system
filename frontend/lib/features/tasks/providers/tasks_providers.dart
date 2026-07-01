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

/// The list of tasks from the backend. Invalidate to refresh; use
/// [TasksNotifier.toggleDone] for an optimistic completion toggle.
class TasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() {
    return ref.watch(tasksRepositoryProvider).list();
  }

  /// Flips a task's completion locally for instant feedback, then persists it
  /// and reconciles with the server. Rolls back the local change on failure.
  Future<void> toggleDone(int id, bool done) async {
    final List<Task>? current = state.asData?.value;
    if (current != null) {
      state = AsyncData<List<Task>>(<Task>[
        for (final Task t in current)
          if (t.id == id) t.copyWith(done: done) else t,
      ]);
    }
    try {
      await ref.read(tasksRepositoryProvider).setDone(id, done: done);
    } catch (error, stack) {
      if (current != null) {
        state = AsyncData<List<Task>>(current);
      }
      Error.throwWithStackTrace(error, stack);
    }
    ref.invalidateSelf();
  }
}

final AsyncNotifierProvider<TasksNotifier, List<Task>> tasksProvider =
    AsyncNotifierProvider<TasksNotifier, List<Task>>(TasksNotifier.new);
