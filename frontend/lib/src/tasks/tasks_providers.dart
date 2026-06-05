import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/task.dart';
import 'tasks_repository.dart';

/// The repository, built from the shared Dio client.
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(dioProvider));
});

/// The list of tasks, fetched from the backend. Call `ref.invalidate` to refresh.
final tasksProvider = FutureProvider<List<Task>>((ref) {
  return ref.watch(tasksRepositoryProvider).list();
});
