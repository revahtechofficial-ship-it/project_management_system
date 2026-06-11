import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/team_member.dart';
import '../../../data/repositories/team_repository.dart';
import '../../../providers/dio_provider.dart';

/// The team repository, built from the shared Dio client (AGENTS.md §1).
final Provider<TeamRepository> teamRepositoryProvider =
    Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(dioProvider));
});

/// The workspace members (registered users) from the backend. Invalidate to
/// refresh.
final FutureProvider<List<TeamMember>> teamMembersProvider =
    FutureProvider<List<TeamMember>>((ref) {
  return ref.watch(teamRepositoryProvider).list();
});
