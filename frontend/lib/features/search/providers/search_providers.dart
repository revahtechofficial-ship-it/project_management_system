import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/search_repository.dart';
import '../../../providers/dio_provider.dart';

/// The search repository, built from the shared Dio client (AGENTS.md §1).
final Provider<SearchRepository> searchRepositoryProvider =
    Provider<SearchRepository>((ref) {
      return SearchRepository(ref.watch(dioProvider));
    });
