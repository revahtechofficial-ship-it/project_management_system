import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/one_on_one.dart';
import '../../../data/repositories/one_on_ones_repository.dart';
import '../../../providers/dio_provider.dart';

/// The 1:1s repository, from the shared Dio client (AGENTS.md §1).
final Provider<OneOnOnesRepository> oneOnOnesRepositoryProvider =
    Provider<OneOnOnesRepository>((ref) {
      return OneOnOnesRepository(ref.watch(dioProvider));
    });

/// The current user's 1:1s. Invalidate to refresh.
final FutureProvider<List<OneOnOne>> oneOnOnesProvider =
    FutureProvider<List<OneOnOne>>((ref) {
      return ref.watch(oneOnOnesRepositoryProvider).list();
    });

/// A single 1:1 with its items, keyed by meeting id.
final oneOnOneDetailProvider = FutureProvider.family<OneOnOneDetail, int>((
  ref,
  int id,
) {
  return ref.watch(oneOnOnesRepositoryProvider).get(id);
});
