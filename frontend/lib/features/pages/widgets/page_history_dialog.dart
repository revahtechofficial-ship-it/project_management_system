import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/async_states.dart';
import '../../../data/models/page_version.dart';
import '../providers/pages_providers.dart';

/// Opens the version history for a page. Returns true when a revision was
/// restored, so the caller can reload the editor.
Future<bool?> showPageHistoryDialog(BuildContext context, int pageId) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) => _PageHistoryDialog(pageId: pageId),
  );
}

class _PageHistoryDialog extends ConsumerWidget {
  const _PageHistoryDialog({required this.pageId});
  final int pageId;

  Future<void> _restore(
      BuildContext context, WidgetRef ref, PageVersion v) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Restore this version?'),
            content: const Text(
                'The current content is saved to history first, so you can '
                'undo this.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    try {
      await ref.read(pagesRepositoryProvider).restoreVersion(pageId, v.id);
      ref.invalidate(pageVersionsProvider(pageId));
      if (context.mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not restore: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PageVersion>> async =
        ref.watch(pageVersionsProvider(pageId));
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.history),
                  const SizedBox(width: 10),
                  const Text('Version history',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: async.when(
                loading: () =>
                    const SizedBox(height: 200, child: LoadingView()),
                error: (Object e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorNotice(error: e),
                ),
                data: (List<PageVersion> versions) {
                  if (versions.isEmpty) {
                    return const EmptyState(
                      icon: Icons.history_toggle_off,
                      title: 'No history yet',
                      message: 'Earlier revisions appear here as the document '
                          'is edited over time.',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: versions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int i) => _VersionTile(
                      version: versions[i],
                      onRestore: () => _restore(context, ref, versions[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({required this.version, required this.onRestore});
  final PageVersion version;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final PageVersion v = version;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  v.title.isEmpty ? 'Untitled' : v.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    if (v.editorName.isNotEmpty) v.editorName,
                    relativeTime(v.createdAt),
                  ].join(' · '),
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                if (v.preview.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    v.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRestore, child: const Text('Restore')),
        ],
      ),
    );
  }
}
