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

/// The Pages workspace: collaborative Docs (live), plus Whiteboard and Form
/// tabs (coming soon). The selected tab is ephemeral UI state (AGENTS.md §1).
class PagesPage extends ConsumerStatefulWidget {
  const PagesPage({super.key});

  @override
  ConsumerState<PagesPage> createState() => _PagesPageState();
}

class _PagesPageState extends ConsumerState<PagesPage> {
  PageType _tab = PageType.doc;

  Future<void> _openDoc(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => DocEditorScreen(pageId: id),
      ),
    );
    ref.invalidate(pagesByTypeProvider(PageType.doc));
  }

  Future<void> _newDoc() async {
    try {
      final WorkspacePage page = await ref
          .read(pagesRepositoryProvider)
          .create(type: PageType.doc);
      ref.invalidate(pagesByTypeProvider(PageType.doc));
      if (mounted) {
        await _openDoc(page.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not create doc: $e')));
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
            subtitle: 'Docs, whiteboards and forms',
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
                FilledButton.icon(
                  onPressed: _newDoc,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New doc'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _tab == PageType.doc
                ? _DocsTree(onOpen: _openDoc)
                : _ComingSoon(type: _tab),
          ),
        ],
      ),
    );
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

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.type});

  final PageType type;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(type.icon, size: 56, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            '${type.label} is coming soon',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            type == PageType.whiteboard
                ? 'A freeform canvas for sketches and sticky notes.'
                : 'Build intake forms and collect responses.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
