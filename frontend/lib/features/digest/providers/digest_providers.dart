import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/digest_data.dart';
import '../../../data/repositories/digest_repository.dart';
import '../../../providers/dio_provider.dart';

/// The digest repository, from the shared Dio client (AGENTS.md §1).
final Provider<DigestRepository> digestRepositoryProvider =
    Provider<DigestRepository>((ref) {
  return DigestRepository(ref.watch(dioProvider));
});

/// The current user's digest. Invalidate to refresh.
final FutureProvider<DigestData> digestProvider =
    FutureProvider<DigestData>((ref) {
  return ref.watch(digestRepositoryProvider).get();
});
