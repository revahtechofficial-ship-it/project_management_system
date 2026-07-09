import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/expense.dart';
import '../../../data/repositories/expenses_repository.dart';
import '../../../providers/dio_provider.dart';

/// The expenses repository, from the shared Dio client (AGENTS.md §1).
final Provider<ExpensesRepository> expensesRepositoryProvider =
    Provider<ExpensesRepository>((ref) {
      return ExpensesRepository(ref.watch(dioProvider));
    });

/// Every expense claim. Invalidate to refresh after a change.
final FutureProvider<List<Expense>> expensesProvider =
    FutureProvider<List<Expense>>((ref) {
      return ref.watch(expensesRepositoryProvider).list();
    });
