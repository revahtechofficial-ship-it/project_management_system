import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/task_template.dart';
import '../../../data/repositories/task_templates_repository.dart';
import '../../../providers/dio_provider.dart';

/// The task-templates repository, from the shared Dio client (AGENTS.md §1).
final Provider<TaskTemplatesRepository> taskTemplatesRepositoryProvider =
    Provider<TaskTemplatesRepository>((ref) {
      return TaskTemplatesRepository(ref.watch(dioProvider));
    });

/// All saved task templates. Invalidate to refresh after a save/delete.
final FutureProvider<List<TaskTemplate>> taskTemplatesProvider =
    FutureProvider<List<TaskTemplate>>((ref) {
      return ref.watch(taskTemplatesRepositoryProvider).list();
    });
