import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/objective.dart';
import '../../../data/repositories/objectives_repository.dart';
import '../../../providers/dio_provider.dart';

/// The objectives repository, from the shared Dio client (AGENTS.md §1).
final Provider<ObjectivesRepository> objectivesRepositoryProvider =
    Provider<ObjectivesRepository>((ref) {
      return ObjectivesRepository(ref.watch(dioProvider));
    });

/// All objectives (with their key results). Invalidate to refresh.
final FutureProvider<List<Objective>> objectivesProvider =
    FutureProvider<List<Objective>>((ref) {
      return ref.watch(objectivesRepositoryProvider).list();
    });
