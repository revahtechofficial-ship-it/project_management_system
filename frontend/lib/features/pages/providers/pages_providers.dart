import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/enums/page_type.dart';
import '../../../data/models/page_backlink.dart';
import '../../../data/models/page_share.dart';
import '../../../data/models/page_version.dart';
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

/// Reusable templates of a given type (e.g. whiteboards). Invalidate to refresh.
final pageTemplatesProvider =
    FutureProvider.family<List<WorkspacePage>, PageType>((ref, PageType type) {
      return ref.watch(pagesRepositoryProvider).list(type, templates: true);
    });

/// The users a (private) page is shared with. Invalidate after changing shares.
final pageSharesProvider = FutureProvider.family<List<PageShare>, int>((
  ref,
  int id,
) {
  return ref.watch(pagesRepositoryProvider).shares(id);
});

/// A page's saved revisions, keyed by page id. Invalidate after a restore.
final pageVersionsProvider = FutureProvider.family<List<PageVersion>, int>((
  ref,
  int id,
) {
  return ref.watch(pagesRepositoryProvider).versions(id);
});

/// The pages that link to a page (backlinks), keyed by page id.
final pageBacklinksProvider = FutureProvider.family<List<PageBacklink>, int>((
  ref,
  int id,
) {
  return ref.watch(pagesRepositoryProvider).backlinks(id);
});
