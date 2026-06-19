import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/task_dependency.dart';
import '../../../data/repositories/dependencies_repository.dart';
import '../../../providers/dio_provider.dart';

/// The dependencies repository, built from the shared Dio client (AGENTS.md §1).
final Provider<DependenciesRepository> dependenciesRepositoryProvider =
    Provider<DependenciesRepository>((ref) {
      return DependenciesRepository(ref.watch(dioProvider));
    });

/// Every task dependency in the workspace. Invalidate to refresh.
final FutureProvider<List<TaskDependency>> dependenciesProvider =
    FutureProvider<List<TaskDependency>>((ref) {
      return ref.watch(dependenciesRepositoryProvider).list();
    });
