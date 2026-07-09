import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/asset.dart';
import '../../../data/repositories/assets_repository.dart';
import '../../../providers/dio_provider.dart';

/// The assets repository, from the shared Dio client (AGENTS.md §1).
final Provider<AssetsRepository> assetsRepositoryProvider =
    Provider<AssetsRepository>((ref) {
      return AssetsRepository(ref.watch(dioProvider));
    });

/// The full company inventory. Invalidate to refresh after a change.
final FutureProvider<List<Asset>> assetsProvider = FutureProvider<List<Asset>>((
  ref,
) {
  return ref.watch(assetsRepositoryProvider).list();
});
