import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/release.dart';
import '../../../data/repositories/releases_repository.dart';
import '../../../providers/dio_provider.dart';

/// The releases repository (AGENTS.md §1).
final Provider<ReleasesRepository> releasesRepositoryProvider =
    Provider<ReleasesRepository>((ref) {
      return ReleasesRepository(ref.watch(dioProvider));
    });

/// All planned releases, soonest target first. Invalidate to refresh.
final FutureProvider<List<Release>> releasesProvider =
    FutureProvider<List<Release>>((ref) {
      return ref.watch(releasesRepositoryProvider).list();
    });
