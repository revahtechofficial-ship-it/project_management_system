import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/folder.dart';
import '../../../data/models/space.dart';
import '../../../data/repositories/spaces_repository.dart';
import '../../../providers/dio_provider.dart';

/// The spaces/folders repository, from the shared Dio client (AGENTS.md §1).
final Provider<SpacesRepository> spacesRepositoryProvider =
    Provider<SpacesRepository>((ref) {
      return SpacesRepository(ref.watch(dioProvider));
    });

/// All spaces, ordered. Invalidate to refresh.
final FutureProvider<List<Space>> spacesProvider = FutureProvider<List<Space>>((
  ref,
) {
  return ref.watch(spacesRepositoryProvider).listSpaces();
});

/// All folders across spaces, ordered. Invalidate to refresh.
final FutureProvider<List<Folder>> foldersProvider =
    FutureProvider<List<Folder>>((ref) {
      return ref.watch(spacesRepositoryProvider).listFolders();
    });
