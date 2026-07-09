import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/account_data_repository.dart';
import '../../../providers/dio_provider.dart';

/// The account-data repository, from the shared Dio client (AGENTS.md §1).
final Provider<AccountDataRepository> accountDataRepositoryProvider =
    Provider<AccountDataRepository>((ref) {
      return AccountDataRepository(ref.watch(dioProvider));
    });
