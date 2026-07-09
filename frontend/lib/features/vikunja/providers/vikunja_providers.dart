import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vikunja_project.dart';
import '../../../data/repositories/vikunja_repository.dart';
import '../../../providers/dio_provider.dart';

/// The Vikunja repository, built from the shared (auth-attaching) Dio client.
final Provider<VikunjaRepository> vikunjaRepositoryProvider =
    Provider<VikunjaRepository>((ref) {
      return VikunjaRepository(ref.watch(dioProvider));
    });

/// The user's Vikunja projects, fetched through the BFF bridge.
final FutureProvider<List<VikunjaProject>> vikunjaProjectsProvider =
    FutureProvider<List<VikunjaProject>>((ref) {
      return ref.watch(vikunjaRepositoryProvider).listProjects();
    });
