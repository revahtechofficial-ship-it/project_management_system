import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/favorite.dart';
import '../../features/favorites/providers/favorites_providers.dart';
import '../constants/app_colors.dart';

/// A star toggle that favorites/unfavorites an item (a task, project or page)
/// for quick access. Shared across features (AGENTS.md §1 `core/widgets`).
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.kind,
    required this.itemId,
    required this.label,
    required this.route,
    this.size = 20,
  });

  final String kind;
  final int itemId;
  final String label;
  final String route;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Favorite> favorites =
        ref.watch(favoritesProvider).asData?.value ?? const <Favorite>[];
    final bool isFav = favorites.any(
      (Favorite f) => f.kind == kind && f.itemId == itemId,
    );
    return IconButton(
      tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
      visualDensity: VisualDensity.compact,
      iconSize: size,
      icon: Icon(
        isFav ? Icons.star : Icons.star_border,
        color: isFav ? AppColors.amber : null,
      ),
      onPressed: () async {
        final repo = ref.read(favoritesRepositoryProvider);
        if (isFav) {
          await repo.remove(kind, itemId);
        } else {
          await repo.add(
            kind: kind,
            itemId: itemId,
            label: label,
            route: route,
          );
        }
        ref.invalidate(favoritesProvider);
      },
    );
  }
}
