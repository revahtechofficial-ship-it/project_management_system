import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/enums/page_type.dart';
import '../../../data/models/workspace_page.dart';
import '../../../data/repositories/pages_repository.dart';
import '../../../providers/dio_provider.dart';

/// The pages repository, from the shared Dio client (AGENTS.md §1).
final Provider<PagesRepository> pagesRepositoryProvider =
    Provider<PagesRepository>((ref) {
      return PagesRepository(ref.watch(dioProvider));
    });

/// Pages of a given type (e.g. all Docs), excluding templates. Invalidate to
/// refresh after a create/edit/delete.
final pagesByTypeProvider =
    FutureProvider.family<List<WorkspacePage>, PageType>((ref, PageType type) {
      return ref.watch(pagesRepositoryProvider).list(type);
    });

/// The reusable Doc templates. Invalidate after saving a new template.
final docTemplatesProvider = FutureProvider<List<WorkspacePage>>((ref) {
  return ref.watch(pagesRepositoryProvider).list(PageType.doc, templates: true);
});
