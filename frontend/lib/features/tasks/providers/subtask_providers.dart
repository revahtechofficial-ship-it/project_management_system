import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/checklist_item.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/checklist_repository.dart';
import '../../../providers/dio_provider.dart';
import 'tasks_providers.dart';

/// Subtasks of a given parent task. Invalidate to refresh.
final subtasksProvider =
    FutureProvider.family<List<Task>, int>((ref, int parentId) {
  return ref.watch(tasksRepositoryProvider).listSubtasks(parentId);
});

/// The checklist repository, built from the shared Dio client (AGENTS.md §1).
final Provider<ChecklistRepository> checklistRepositoryProvider =
    Provider<ChecklistRepository>((ref) {
  return ChecklistRepository(ref.watch(dioProvider));
});

/// Checklist items of a given task. Invalidate to refresh.
final checklistProvider =
    FutureProvider.family<List<ChecklistItem>, int>((ref, int taskId) {
  return ref.watch(checklistRepositoryProvider).list(taskId);
});
