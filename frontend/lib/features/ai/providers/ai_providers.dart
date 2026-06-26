import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/ai_repository.dart';
import '../../../providers/dio_provider.dart';

/// The AI repository, built from the shared Dio client (AGENTS.md §1).
final Provider<AiRepository> aiRepositoryProvider = Provider<AiRepository>((
  ref,
) {
  return AiRepository(ref.watch(dioProvider));
});

/// Whether AI is configured on the backend (drives the not-configured banner).
final FutureProvider<AiStatus> aiStatusProvider = FutureProvider<AiStatus>((
  ref,
) {
  return ref.watch(aiRepositoryProvider).status();
});
