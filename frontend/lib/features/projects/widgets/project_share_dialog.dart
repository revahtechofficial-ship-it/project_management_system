import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../providers/project_share_providers.dart';

/// Opens the public-share dialog for a project.
Future<void> showProjectShareDialog(
  BuildContext context,
  int projectId,
  String projectName,
) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext _) =>
        _ProjectShareDialog(projectId: projectId, projectName: projectName),
  );
}

String _shareUrl(String token) => '${Uri.base.origin}/#/share/project/$token';

class _ProjectShareDialog extends ConsumerStatefulWidget {
  const _ProjectShareDialog({
    required this.projectId,
    required this.projectName,
  });
  final int projectId;
  final String projectName;

  @override
  ConsumerState<_ProjectShareDialog> createState() =>
      _ProjectShareDialogState();
}

class _ProjectShareDialogState extends ConsumerState<_ProjectShareDialog> {
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      await ref.read(projectShareRepositoryProvider).enable(widget.projectId);
      ref.invalidate(projectShareTokenProvider(widget.projectId));
    } catch (e) {
      if (mounted) {
        context.showError('Could not create link: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _revoke() async {
    setState(() => _busy = true);
    try {
      await ref.read(projectShareRepositoryProvider).revoke(widget.projectId);
      ref.invalidate(projectShareTokenProvider(widget.projectId));
    } catch (e) {
      if (mounted) {
        context.showError('Could not stop sharing: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? token =
        ref.watch(projectShareTokenProvider(widget.projectId)).asData?.value;
    return AlertDialog(
      title: const Text('Share project'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Anyone with the link gets a read-only view of '
              '"${widget.projectName}" and its tasks — no sign-in needed.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (token == null)
              Row(
                children: <Widget>[
                  Icon(Icons.lock_outline,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Not shared')),
                  FilledButton.icon(
                    onPressed: _busy ? null : _enable,
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Create link'),
                  ),
                ],
              )
            else ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _shareUrl(token),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy link',
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () => context.copyToClipboard(
                          _shareUrl(token),
                          label: 'Link copied'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : _revoke,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text('Stop sharing'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
