import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/git_commit.dart';
import '../../../data/models/git_repo.dart';
import '../../../data/repositories/git_repository.dart';
import '../../../providers/dio_provider.dart';

/// The git repository client, from the shared Dio client (AGENTS.md §1).
final Provider<GitRepository> gitRepositoryProvider = Provider<GitRepository>((
  ref,
) {
  return GitRepository(ref.watch(dioProvider));
});

/// Registered repositories. Invalidate to refresh after a change.
final FutureProvider<List<GitRepo>> gitReposProvider =
    FutureProvider<List<GitRepo>>((ref) {
      return ref.watch(gitRepositoryProvider).repos();
    });

/// Recent commit activity across repositories. Invalidate to refresh.
final FutureProvider<List<GitCommit>> gitCommitsProvider =
    FutureProvider<List<GitCommit>>((ref) {
      return ref.watch(gitRepositoryProvider).commits();
    });
