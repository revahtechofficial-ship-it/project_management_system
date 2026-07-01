import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/skill.dart';
import '../../../data/repositories/skills_repository.dart';
import '../../../providers/dio_provider.dart';

/// The skills repository, from the shared Dio client (AGENTS.md §1).
final Provider<SkillsRepository> skillsRepositoryProvider =
    Provider<SkillsRepository>((ref) {
  return SkillsRepository(ref.watch(dioProvider));
});

/// Every member's skills, for the team matrix. Invalidate to refresh.
final FutureProvider<List<Skill>> allSkillsProvider =
    FutureProvider<List<Skill>>((ref) {
  return ref.watch(skillsRepositoryProvider).all();
});

/// The current user's own skills. Invalidate to refresh.
final FutureProvider<List<Skill>> mySkillsProvider =
    FutureProvider<List<Skill>>((ref) {
  return ref.watch(skillsRepositoryProvider).mine();
});
