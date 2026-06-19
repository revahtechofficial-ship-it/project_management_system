import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/page_header.dart';
import '../../data/enums/page_type.dart';
import '../../data/models/workspace_page.dart';
import 'providers/pages_providers.dart';
import 'widgets/doc_editor_screen.dart';
import 'widgets/form_editor_screen.dart';
import 'widgets/whiteboard_editor_screen.dart';

/// The Pages workspace: collaborative Docs (live), plus Whiteboard and Form
/// tabs (coming soon). The selected tab is ephemeral UI state (AGENTS.md §1).
class PagesPage extends ConsumerStatefulWidget {
  const PagesPage({super.key});

  @override
  ConsumerState<PagesPage> createState() => _PagesPageState();
}

class _PagesPageState extends ConsumerState<PagesPage> {
  PageType _tab = PageType.doc;

  Future<void> _openPage(int id, PageType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => switch (type) {
          PageType.whiteboard => WhiteboardEditorScreen(pageId: id),
          PageType.form => FormEditorScreen(pageId: id),
          _ => DocEditorScreen(pageId: id),
        },
      ),
    );
    ref.invalidate(pagesByTypeProvider(type));
    ref.invalidate(docTemplatesProvider);
  }

  Future<void> _create(PageType type, {WorkspacePage? from}) async {
    try {
      // Copying a template needs its full body, which the list omits.
      String body = '';
      String title = '';
      if (from != null) {
        final WorkspacePage full = await ref
            .read(pagesRepositoryProvider)
            .get(from.id);
        body = full.body;
        title = full.title;
      }
      final WorkspacePage page = await ref
          .read(pagesRepositoryProvider)
          .create(type: type, title: title, body: body);
      ref.invalidate(pagesByTypeProvider(type));
      if (mounted) {
        await _openPage(page.id, type);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not create: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Pages',
            subtitle: 'Docs, SOPs, whiteboards and forms',
            actions: <Widget>[
              SegmentedButton<PageType>(
                segments: <ButtonSegment<PageType>>[
                  for (final PageType t in PageType.values)
                    ButtonSegment<PageType>(
                      value: t,
                      icon: Icon(t.icon, size: 18),
                      label: Text(t.label),
                    ),
                ],
                selected: <PageType>{_tab},
                showSelectedIcon: false,
                onSelectionChanged: (Set<PageType> s) =>
                    setState(() => _tab = s.first),
              ),
              if (_tab == PageType.doc)
                _TemplateMenu(
                  type: PageType.doc,
                  onPick: (WorkspacePage t) => _create(PageType.doc, from: t),
                ),
              if (_tab == PageType.doc)
                FilledButton.icon(
                  onPressed: () => _create(PageType.doc),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New doc'),
                ),
              if (_tab == PageType.sop)
                FilledButton.icon(
                  onPressed: () => _create(PageType.sop),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New SOP'),
                ),
              if (_tab == PageType.whiteboard)
                _TemplateMenu(
                  type: PageType.whiteboard,
                  onPick: (WorkspacePage t) =>
                      _create(PageType.whiteboard, from: t),
                ),
              if (_tab == PageType.whiteboard)
                FilledButton.icon(
                  onPressed: () => _create(PageType.whiteboard),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New whiteboard'),
                ),
              if (_tab == PageType.form)
                FilledButton.icon(
                  onPressed: () => _create(PageType.form),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New form'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_tab) {
      case PageType.doc:
        return _DocsTree(onOpen: (int id) => _openPage(id, PageType.doc));
      case PageType.sop:
        return _SopList(onOpen: (int id) => _openPage(id, PageType.sop));
      case PageType.whiteboard:
        return _FlatPageList(
          type: PageType.whiteboard,
          icon: Icons.gesture_outlined,
          color: AppColors.violet,
          emptyMessage: 'No whiteboards yet. Create one to start sketching.',
          onOpen: (int id) => _openPage(id, PageType.whiteboard),
        );
      case PageType.form:
        return _FlatPageList(
          type: PageType.form,
          icon: Icons.dynamic_form_outlined,
          color: AppColors.sky,
          emptyMessage: 'No forms yet. Create one to collect responses.',
          onOpen: (int id) => _openPage(id, PageType.form),
        );
    }
  }
}

/// The nested wiki tree of docs, with expand/collapse, search, and a per-row
/// "add subpage" action.
class _DocsTree extends ConsumerStatefulWidget {
  const _DocsTree({required this.onOpen});

  final Future<void> Function(int id) onOpen;

  @override
  ConsumerState<_DocsTree> createState() => _DocsTreeState();
}

class _DocsTreeState extends ConsumerState<_DocsTree> {
  final Set<int> _expanded = <int>{};
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addSubpage(int parentId) async {
    try {
      final WorkspacePage page = await ref
          .read(pagesRepositoryProvider)
          .create(type: PageType.doc, parentId: parentId);
      ref.invalidate(pagesByTypeProvider(PageType.doc));
      setState(() => _expanded.add(parentId));
      await widget.onOpen(page.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add subpage: $e')));
      }
    }
  }

  /// Groups pages under their (resolved) parent id; orphans become roots.
  Map<int?, List<WorkspacePage>> _byParent(List<WorkspacePage> items) {
    final Set<int> ids = <int>{for (final WorkspacePage p in items) p.id};
    final Map<int?, List<WorkspacePage>> out = <int?, List<WorkspacePage>>{};
    for (final WorkspacePage p in items) {
      final int? key = (p.parentId != null && ids.contains(p.parentId))
          ? p.parentId
          : null;
      out.putIfAbsent(key, () => <WorkspacePage>[]).add(p);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<WorkspacePage>> docs = ref.watch(
      pagesByTypeProvider(PageType.doc),
    );
    return Column(
      children: <Widget>[
        TextField(
          controller: _search,
          onChanged: (String v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search docs…',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: docs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, _) =>
                Center(child: Text('Failed to load docs:\n$e')),
            data: (List<WorkspacePage> items) => _content(items),
          ),
        ),
      ],
    );
  }

  Widget _content(List<WorkspacePage> items) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.description_outlined,
        message: 'No docs yet. Create your first one.',
      );
    }
    // Search mode: a flat filtered list, ignoring hierarchy.
    if (_query.isNotEmpty) {
      final String q = _query.toLowerCase();
      final List<WorkspacePage> hits = items
          .where((WorkspacePage p) => p.title.toLowerCase().contains(q))
          .toList(growable: false);
      if (hits.isEmpty) {
        return const EmptyState(
          icon: Icons.search_off,
          message: 'No docs match your search.',
        );
      }
      return ListView(
        children: <Widget>[
          for (final WorkspacePage p in hits)
            _DocTreeRow(
              page: p,
              depth: 0,
              hasChildren: false,
              expanded: false,
              onToggle: null,
              onOpen: () => widget.onOpen(p.id),
              onAddSubpage: () => _addSubpage(p.id),
            ),
        ],
      );
    }
    // Tree mode.
    final Map<int?, List<WorkspacePage>> byParent = _byParent(items);
    final List<Widget> rows = <Widget>[];
    void walk(int? parent, int depth) {
      for (final WorkspacePage p
          in byParent[parent] ?? const <WorkspacePage>[]) {
        final bool hasChildren =
            (byParent[p.id] ?? const <WorkspacePage>[]).isNotEmpty;
        final bool expanded = _expanded.contains(p.id);
        rows.add(
          _DocTreeRow(
            page: p,
            depth: depth,
            hasChildren: hasChildren,
            expanded: expanded,
            onToggle: hasChildren
                ? () => setState(() {
                    if (!_expanded.remove(p.id)) {
                      _expanded.add(p.id);
                    }
                  })
                : null,
            onOpen: () => widget.onOpen(p.id),
            onAddSubpage: () => _addSubpage(p.id),
          ),
        );
        if (expanded) {
          walk(p.id, depth + 1);
        }
      }
    }

    walk(null, 0);
    return ListView(children: rows);
  }
}

/// A single row in the docs tree: indentation, expand toggle, title, and an
/// add-subpage button.
class _DocTreeRow extends StatelessWidget {
  const _DocTreeRow({
    required this.page,
    required this.depth,
    required this.hasChildren,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
    required this.onAddSubpage,
  });

  final WorkspacePage page;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggle;
  final VoidCallback onOpen;
  final VoidCallback onAddSubpage;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.only(left: depth * 18.0, top: 2, bottom: 2),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: hasChildren
                  ? IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 20,
                      ),
                      onPressed: onToggle,
                    )
                  : const SizedBox.shrink(),
            ),
            Icon(Icons.description_outlined, size: 18, color: AppColors.brand),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  page.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Text(
              relativeTime(page.updatedAt),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            IconButton(
              tooltip: 'Add subpage',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add, size: 18),
              onPressed: onAddSubpage,
            ),
          ],
        ),
      ),
    );
  }
}

/// A "From template" menu beside "New doc", shown only when templates exist.
class _TemplateMenu extends ConsumerWidget {
  const _TemplateMenu({required this.type, required this.onPick});

  final PageType type;
  final ValueChanged<WorkspacePage> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<WorkspacePage> templates =
        (type == PageType.doc
                ? ref.watch(docTemplatesProvider)
                : ref.watch(pageTemplatesProvider(type)))
            .asData
            ?.value ??
        const <WorkspacePage>[];
    if (templates.isEmpty) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<WorkspacePage>(
      tooltip: 'New from template',
      onSelected: onPick,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<WorkspacePage>>[
        for (final WorkspacePage t in templates)
          PopupMenuItem<WorkspacePage>(value: t, child: Text(t.displayTitle)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.bookmark_outline, size: 18),
            SizedBox(width: 8),
            Text('From template'),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// The list of SOPs, each showing its owner, category and review status.
class _SopList extends ConsumerWidget {
  const _SopList({required this.onOpen});

  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WorkspacePage>> sops = ref.watch(
      pagesByTypeProvider(PageType.sop),
    );
    return sops.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => Center(child: Text('Failed to load SOPs:\n$e')),
      data: (List<WorkspacePage> items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.fact_check_outlined,
            message:
                'No SOPs yet. Create one to document a standard procedure.',
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int i) =>
              _SopCard(page: items[i], onTap: () => onOpen(items[i].id)),
        );
      },
    );
  }
}

class _SopCard extends StatelessWidget {
  const _SopCard({required this.page, required this.onTap});

  final WorkspacePage page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.teal.withValues(alpha: 0.15),
          child: const Icon(Icons.fact_check_outlined, color: AppColors.teal),
        ),
        title: Text(
          page.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          <String>[
            if (page.category.isNotEmpty) page.category,
            if (page.ownerName.isNotEmpty) 'Owner: ${page.ownerName}',
            'Edited ${relativeTime(page.updatedAt)}',
          ].join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _ReviewBadge(page: page),
      ),
    );
  }
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({required this.page});

  final WorkspacePage page;

  @override
  Widget build(BuildContext context) {
    if (page.reviewAt == null) {
      return const Icon(Icons.chevron_right);
    }
    final bool due = page.needsReview;
    final Color color = due ? AppColors.rose : AppColors.slate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        due ? 'Needs review' : 'Review ${shortDate(page.reviewAt!.toLocal())}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// A simple flat list of pages of one [type] (used for whiteboards and forms).
class _FlatPageList extends ConsumerWidget {
  const _FlatPageList({
    required this.type,
    required this.icon,
    required this.color,
    required this.emptyMessage,
    required this.onOpen,
  });

  final PageType type;
  final IconData icon;
  final Color color;
  final String emptyMessage;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WorkspacePage>> async = ref.watch(
      pagesByTypeProvider(type),
    );
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => Center(child: Text('Failed to load:\n$e')),
      data: (List<WorkspacePage> items) {
        if (items.isEmpty) {
          return EmptyState(icon: icon, message: emptyMessage);
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int i) {
            final WorkspacePage p = items[i];
            return Material(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => onOpen(p.id),
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                title: Text(
                  p.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Edited ${relativeTime(p.updatedAt)}'
                  '${p.updatedByName.isEmpty ? '' : ' by ${p.updatedByName}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }
}
