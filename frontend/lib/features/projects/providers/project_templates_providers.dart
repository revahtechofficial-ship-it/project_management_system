import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/project_template.dart';
import '../../../data/repositories/project_templates_repository.dart';
import '../../../providers/dio_provider.dart';

/// The project-templates repository, from the shared Dio client (AGENTS.md §1).
final Provider<ProjectTemplatesRepository> projectTemplatesRepositoryProvider =
    Provider<ProjectTemplatesRepository>((ref) {
      return ProjectTemplatesRepository(ref.watch(dioProvider));
    });

/// All saved project templates. Invalidate to refresh after a save/delete.
final FutureProvider<List<ProjectTemplate>> projectTemplatesProvider =
    FutureProvider<List<ProjectTemplate>>((ref) {
      return ref.watch(projectTemplatesRepositoryProvider).list();
    });
