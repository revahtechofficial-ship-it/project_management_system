import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/saved_filter.dart';
import '../../../data/repositories/saved_filters_repository.dart';
import '../../../providers/dio_provider.dart';

/// The saved-filters repository (AGENTS.md §1).
final Provider<SavedFiltersRepository> savedFiltersRepositoryProvider =
    Provider<SavedFiltersRepository>((ref) {
      return SavedFiltersRepository(ref.watch(dioProvider));
    });

/// The current user's saved task filters. Invalidate to refresh.
final FutureProvider<List<SavedFilter>> savedFiltersProvider =
    FutureProvider<List<SavedFilter>>((ref) {
      return ref.watch(savedFiltersRepositoryProvider).list();
    });
