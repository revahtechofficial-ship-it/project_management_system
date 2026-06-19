import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/automation_rule.dart';
import '../../../data/repositories/automations_repository.dart';
import '../../../providers/dio_provider.dart';

/// The automations repository, from the shared Dio client (AGENTS.md §1).
final Provider<AutomationsRepository> automationsRepositoryProvider =
    Provider<AutomationsRepository>((ref) {
      return AutomationsRepository(ref.watch(dioProvider));
    });

/// All automation rules. Invalidate to refresh.
final FutureProvider<List<AutomationRule>> automationsProvider =
    FutureProvider<List<AutomationRule>>((ref) {
      return ref.watch(automationsRepositoryProvider).list();
    });
