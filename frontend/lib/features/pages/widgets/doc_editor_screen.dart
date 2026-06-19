import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/workspace_page.dart';
import '../providers/pages_providers.dart';

/// A focused, full-screen editor for a single Doc. Loads the page body, lets
/// the user edit the title and Markdown/plain-text body, and saves on demand
/// (and on exit). Pushed via [Navigator] as an ephemeral screen (AGENTS.md §9).
class DocEditorScreen extends ConsumerStatefulWidget {
  const DocEditorScreen({super.key, required this.pageId});

  final int pageId;

  @override
  ConsumerState<DocEditorScreen> createState() => _DocEditorScreenState();
}

class _DocEditorScreenState extends ConsumerState<DocEditorScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  WorkspacePage? _page;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final WorkspacePage page = await ref
          .read(pagesRepositoryProvider)
          .get(widget.pageId);
      if (!mounted) {
        return;
      }
      _title.text = page.title;
      _body.text = page.body;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<bool> _save({bool silent = false}) async {
    if (_page == null) {
      return true;
    }
    setState(() => _saving = true);
    try {
      final WorkspacePage saved = await ref
          .read(pagesRepositoryProvider)
          .update(
            widget.pageId,
            title: _title.text.trim(),
            body: _body.text,
            icon: _page!.icon,
          );
      if (mounted) {
        setState(() {
          _page = saved;
          _saving = false;
          _dirty = false;
        });
        if (!silent) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved')));
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
      return false;
    }
  }

  Future<void> _delete() async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Delete document?'),
            content: const Text('This cannot be undone.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    try {
      await ref.read(pagesRepositoryProvider).delete(widget.pageId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (didPop) {
          return;
        }
        final NavigatorState nav = Navigator.of(context);
        if (_dirty) {
          await _save(silent: true);
        }
        if (mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Document'),
          actions: <Widget>[
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              TextButton.icon(
                onPressed: _dirty ? () => _save() : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save'),
              ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _page == null ? null : _delete,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text('Could not load document:\n$_error'))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextField(
                          controller: _title,
                          onChanged: (_) => setState(() => _dirty = true),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Untitled',
                          ),
                        ),
                        if (_page != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Edited ${relativeTime(_page!.updatedAt)}'
                              '${_page!.updatedByName.isEmpty ? '' : ' by ${_page!.updatedByName}'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        const Divider(),
                        Expanded(
                          child: TextField(
                            controller: _body,
                            onChanged: (_) => setState(() => _dirty = true),
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Write in plain text or Markdown…',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
