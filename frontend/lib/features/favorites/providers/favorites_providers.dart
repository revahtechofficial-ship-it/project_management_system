import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/favorite.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../../providers/dio_provider.dart';

/// The favorites repository, built from the shared Dio client (AGENTS.md §1).
final Provider<FavoritesRepository> favoritesRepositoryProvider =
    Provider<FavoritesRepository>((ref) {
      return FavoritesRepository(ref.watch(dioProvider));
    });

/// The current user's favorited items. Invalidate to refresh.
final FutureProvider<List<Favorite>> favoritesProvider =
    FutureProvider<List<Favorite>>((ref) {
      return ref.watch(favoritesRepositoryProvider).list();
    });
