import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/custom_field.dart';
import '../../../data/repositories/custom_fields_repository.dart';
import '../../../providers/dio_provider.dart';

/// The custom-fields repository, from the shared Dio client (AGENTS.md §1).
final Provider<CustomFieldsRepository> customFieldsRepositoryProvider =
    Provider<CustomFieldsRepository>((ref) {
      return CustomFieldsRepository(ref.watch(dioProvider));
    });

/// Workspace custom-field definitions. Invalidate to refresh.
final FutureProvider<List<CustomField>> customFieldsProvider =
    FutureProvider<List<CustomField>>((ref) {
      return ref.watch(customFieldsRepositoryProvider).list();
    });

/// A task's custom-field values, keyed by field id. Invalidate to refresh.
final taskFieldValuesProvider = FutureProvider.family<Map<int, String>, int>((
  ref,
  int taskId,
) {
  return ref.watch(customFieldsRepositoryProvider).taskValues(taskId);
});
