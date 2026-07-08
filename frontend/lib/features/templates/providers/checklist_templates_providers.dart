import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/checklist_template.dart';
import '../../../data/repositories/checklist_templates_repository.dart';
import '../../../providers/dio_provider.dart';

/// The checklist-templates repository, from the shared Dio client (AGENTS.md §1).
final Provider<ChecklistTemplatesRepository>
    checklistTemplatesRepositoryProvider =
    Provider<ChecklistTemplatesRepository>((ref) {
  return ChecklistTemplatesRepository(ref.watch(dioProvider));
});

/// All checklist templates. Invalidate to refresh after a change.
final FutureProvider<List<ChecklistTemplate>> checklistTemplatesProvider =
    FutureProvider<List<ChecklistTemplate>>((ref) {
  return ref.watch(checklistTemplatesRepositoryProvider).list();
});
