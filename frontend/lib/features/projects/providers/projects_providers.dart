import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/project.dart';
import '../../../data/repositories/projects_repository.dart';
import '../../../providers/dio_provider.dart';

/// The projects repository, built from the shared Dio client (AGENTS.md §1).
final Provider<ProjectsRepository> projectsRepositoryProvider =
    Provider<ProjectsRepository>((ref) {
  return ProjectsRepository(ref.watch(dioProvider));
});

/// The workspace projects from the backend. Invalidate to refresh.
final FutureProvider<List<Project>> projectsProvider =
    FutureProvider<List<Project>>((ref) {
  return ref.watch(projectsRepositoryProvider).list();
});
