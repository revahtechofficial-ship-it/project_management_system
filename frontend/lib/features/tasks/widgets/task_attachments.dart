import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/attachment.dart';
import '../../../providers/auth_provider.dart';
import '../providers/attachments_providers.dart';
import '../providers/comments_providers.dart';

/// Lists, uploads, downloads and deletes a task's file attachments.
class TaskAttachmentsSection extends ConsumerStatefulWidget {
  const TaskAttachmentsSection({super.key, required this.taskId});
  final int taskId;

  @override
  ConsumerState<TaskAttachmentsSection> createState() =>
      _TaskAttachmentsSectionState();
}

class _TaskAttachmentsSectionState
    extends ConsumerState<TaskAttachmentsSection> {
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    final FilePickerResult? result =
        await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) {
      return;
    }
    final PlatformFile picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(attachmentsRepositoryProvider)
          .upload(widget.taskId, bytes, picked.name);
      ref.invalidate(attachmentsProvider(widget.taskId));
      ref.invalidate(activityProvider(widget.taskId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _download(Attachment a) async {
    final String? token =
        ref.read(authControllerProvider).asData?.value.token;
    if (token == null) {
      return;
    }
    final Uri uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/api/v1/attachments/${a.id}/download'
        '?token=$token');
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  Future<void> _delete(int id) async {
    await ref.read(attachmentsRepositoryProvider).delete(id);
    ref.invalidate(attachmentsProvider(widget.taskId));
    ref.invalidate(activityProvider(widget.taskId));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Attachment> items =
        ref.watch(attachmentsProvider(widget.taskId)).asData?.value ??
            const <Attachment>[];
    final int? me = ref.watch(authControllerProvider).asData?.value.user?.id;
    final bool admin =
        ref.watch(authControllerProvider).asData?.value.isAdmin ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (items.isEmpty)
          Text('No files attached.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        for (final Attachment a in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Icon(a.icon, size: 22, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(a.filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        '${a.sizeLabel} · ${a.uploaderName ?? 'Someone'} · '
                        '${relativeTime(a.createdAt)}',
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Download',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  onPressed: () => _download(a),
                ),
                if (admin || (me != null && a.uploaderId == me))
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _delete(a.id),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _pickAndUpload,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.attach_file, size: 18),
            label: Text(_busy ? 'Uploading…' : 'Attach file'),
          ),
        ),
      ],
    );
  }
}
