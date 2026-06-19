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
                ? _DocsList(onOpen: _openDoc)
                : _ComingSoon(type: _tab),
          ),
        ],
      ),
    );
  }
}

class _DocsList extends ConsumerWidget {
  const _DocsList({required this.onOpen});

  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WorkspacePage>> docs = ref.watch(
      pagesByTypeProvider(PageType.doc),
    );
    return docs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => Center(child: Text('Failed to load docs:\n$e')),
      data: (List<WorkspacePage> items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.description_outlined,
            message: 'No docs yet. Create your first one.',
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int i) =>
              _DocCard(page: items[i], onTap: () => onOpen(items[i].id)),
        );
      },
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.page, required this.onTap});

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
          backgroundColor: AppColors.brand.withValues(alpha: 0.15),
          child: const Icon(Icons.description_outlined, color: AppColors.brand),
        ),
        title: Text(
          page.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Edited ${relativeTime(page.updatedAt)}'
          '${page.updatedByName.isEmpty ? '' : ' by ${page.updatedByName}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
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
