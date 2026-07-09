import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/budget.dart';
import '../../../data/repositories/budgets_repository.dart';
import '../../../providers/dio_provider.dart';

/// The budgets repository, from the shared Dio client (AGENTS.md §1).
final Provider<BudgetsRepository> budgetsRepositoryProvider =
    Provider<BudgetsRepository>((ref) {
      return BudgetsRepository(ref.watch(dioProvider));
    });

/// Every project budget with actuals. Invalidate to refresh after a change.
final FutureProvider<List<Budget>> budgetsProvider =
    FutureProvider<List<Budget>>((ref) {
      return ref.watch(budgetsRepositoryProvider).list();
    });
