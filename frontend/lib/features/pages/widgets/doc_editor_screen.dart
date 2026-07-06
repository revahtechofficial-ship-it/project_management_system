import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/markdown_view.dart';
import '../../../data/enums/page_type.dart';
import '../../../data/models/team_member.dart';
import '../../../data/models/workspace_page.dart';
import '../../../providers/auth_provider.dart';
import '../../chat/providers/chat_providers.dart';
import '../../team/providers/team_providers.dart';
import '../providers/pages_providers.dart';
import 'page_history_dialog.dart';
import 'share_dialog.dart';

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
  final TextEditingController _category = TextEditingController();
  WorkspacePage? _page;
  int? _ownerId;
  DateTime? _reviewAt;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _preview = false;
  String? _error;
  String? _incomingFrom;

  bool get _isSop => _page?.type == PageType.sop;
  bool get _canEdit => _page?.canEdit ?? true;
  bool get _canManage => _page?.canManage ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _category.dispose();
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
      _category.text = page.category;
      _ownerId = page.ownerId;
      _reviewAt = page.reviewAt;
      setState(() {
        _page = page;
        _loading = false;
        // Viewers (and anyone opening a non-empty doc) start in preview.
        _preview = !page.canEdit;
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
    if (_page == null || !_canEdit) {
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
            category: _category.text.trim(),
            ownerId: _ownerId,
            reviewAt: _reviewAt == null ? null : _ymd(_reviewAt!),
          );
      if (mounted) {
        setState(() {
          _page = saved;
          _saving = false;
          _dirty = false;
        });
        if (!silent) {
          context.showSuccess('Saved');
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showError('Could not save: $e');
      }
      return false;
    }
  }

  /// Opens version history. Persists any unsaved edits first (so they land in
  /// history), then reloads the editor if a revision was restored.
  Future<void> _openHistory() async {
    if (_page == null) {
      return;
    }
    if (_dirty && _canEdit) {
      await _save(silent: true);
    }
    if (!mounted) {
      return;
    }
    final bool? restored = await showPageHistoryDialog(context, widget.pageId);
    if (restored == true) {
      await _load();
      if (mounted) {
        context.showSuccess('Version restored');
      }
    }
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickReviewDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reviewAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _reviewAt = picked;
        _dirty = true;
      });
    }
  }

  /// Saves the current title + body as a reusable Doc template.
  Future<void> _saveAsTemplate() async {
    try {
      await ref
          .read(pagesRepositoryProvider)
          .create(
            type: PageType.doc,
            title: _title.text.trim(),
            body: _body.text,
            isTemplate: true,
          );
      ref.invalidate(docTemplatesProvider);
      if (mounted) {
        context.showSuccess('Saved as template');
      }
    } catch (e) {
      if (mounted) {
        context.showError('Could not save template: $e');
      }
    }
  }

  /// Re-fetches the page after a remote edit, replacing the local text. Only
  /// called when the user has no unsaved changes (or chose to reload).
  Future<void> _reloadBody({String? toastFrom}) async {
    try {
      final WorkspacePage p = await ref
          .read(pagesRepositoryProvider)
          .get(widget.pageId);
      if (!mounted) {
        return;
      }
      _title.text = p.title;
      _body.text = p.body;
      _category.text = p.category;
      _ownerId = p.ownerId;
      _reviewAt = p.reviewAt;
      setState(() {
        _page = p;
        _dirty = false;
        _incomingFrom = null;
      });
      if (toastFrom != null) {
        context.showSuccess('Updated by $toastFrom');
      }
    } catch (_) {}
  }

  /// Handles a live "page changed" event from the chat socket.
  void _onPageEvent(Map<String, dynamic> e) {
    if (e['type'] != 'page' || e['page_id'] != widget.pageId) {
      return;
    }
    final int? by = e['updated_by'] as int?;
    final int? me = ref.read(authControllerProvider).asData?.value.user?.id;
    if (by != null && by == me) {
      return; // our own save echoed back
    }
    final String name = e['updated_by_name'] as String? ?? 'Someone';
    if (_dirty || _saving) {
      setState(() => _incomingFrom = name); // let the user choose to reload
    } else {
      _reloadBody(toastFrom: name);
    }
  }

  Future<void> _openShare() async {
    if (_page == null) {
      return;
    }
    await showShareDialog(context, _page!);
    // Visibility may have changed; refresh the page meta (not the editor text).
    try {
      final WorkspacePage fresh = await ref
          .read(pagesRepositoryProvider)
          .get(widget.pageId);
      if (mounted) {
        setState(() => _page = fresh);
      }
    } catch (_) {}
  }

  Future<void> _addSubpage() async {
    try {
      final WorkspacePage child = await ref
          .read(pagesRepositoryProvider)
          .create(type: PageType.doc, parentId: widget.pageId);
      ref.invalidate(pagesByTypeProvider(PageType.doc));
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) =>
                DocEditorScreen(pageId: child.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        context.showError('Could not add subpage: $e');
      }
    }
  }

  /// The ancestor chain (root-first) of the current page, resolved from the
  /// cached docs list. Empty when the page is top-level or the list isn't ready.
  List<WorkspacePage> _ancestors() {
    final List<WorkspacePage> all =
        ref.read(pagesByTypeProvider(PageType.doc)).asData?.value ??
        const <WorkspacePage>[];
    final Map<int, WorkspacePage> byId = <int, WorkspacePage>{
      for (final WorkspacePage p in all) p.id: p,
    };
    final List<WorkspacePage> chain = <WorkspacePage>[];
    int? pid = _page?.parentId;
    int hops = 0;
    while (pid != null && byId.containsKey(pid) && hops < 50) {
      final WorkspacePage a = byId[pid]!;
      chain.insert(0, a);
      pid = a.parentId;
      hops++;
    }
    return chain;
  }

  void _openPage(int id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => DocEditorScreen(pageId: id),
      ),
    );
  }

  // _Breadcrumb is defined at the bottom of this library.

  /// Small chips reflecting the page's sharing state and the viewer's access.
  Widget _statusChips(ColorScheme scheme) {
    final List<Widget> chips = <Widget>[
      if (_page!.isPrivate)
        _chip(Icons.lock_outline, 'Private', AppColors.amber),
      if (!_canEdit) _chip(Icons.visibility_outlined, 'View only', scheme),
    ];
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 8, children: chips),
    );
  }

  Widget _chip(IconData icon, String label, Object color) {
    final Color c = color is Color
        ? color
        : (color as ColorScheme).onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }

  /// The SOP governance bar: owner, category and a review-by date.
  Widget _sopBar() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<TeamMember> team =
        ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int?>(
              initialValue: team.any((TeamMember m) => m.id == _ownerId)
                  ? _ownerId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Owner',
                isDense: true,
                prefixIcon: Icon(Icons.person_outline, size: 18),
              ),
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('No owner'),
                ),
                for (final TeamMember m in team)
                  DropdownMenuItem<int?>(
                    value: m.id,
                    child: Text(
                      m.name.isEmpty ? m.email : m.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (int? v) => setState(() {
                _ownerId = v;
                _dirty = true;
              }),
            ),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _category,
              onChanged: (_) => setState(() => _dirty = true),
              decoration: const InputDecoration(
                labelText: 'Category',
                isDense: true,
                prefixIcon: Icon(Icons.sell_outlined, size: 18),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickReviewDate,
            icon: const Icon(Icons.event, size: 18),
            label: Text(
              _reviewAt == null
                  ? 'Set review date'
                  : 'Review by ${shortDate(_reviewAt!)}',
            ),
          ),
          if (_reviewAt != null)
            IconButton(
              tooltip: 'Clear review date',
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => setState(() {
                _reviewAt = null;
                _dirty = true;
              }),
            ),
        ],
      ),
    );
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
        context.showError('Could not delete: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    ref.listen<AsyncValue<Map<String, dynamic>>>(chatEventsProvider, (
      AsyncValue<Map<String, dynamic>>? _,
      AsyncValue<Map<String, dynamic>> next,
    ) {
      next.whenData(_onPageEvent);
    });
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
            if (_page != null)
              IconButton(
                tooltip: _preview ? 'Edit' : 'Preview',
                isSelected: _preview,
                icon: Icon(
                  _preview ? Icons.edit_note : Icons.visibility_outlined,
                ),
                onPressed: _canEdit
                    ? () => setState(() => _preview = !_preview)
                    : null,
              ),
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
            else if (_canEdit)
              TextButton.icon(
                onPressed: _dirty ? () => _save() : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save'),
              ),
            if (_page != null)
              IconButton(
                tooltip: 'Version history',
                icon: const Icon(Icons.history),
                onPressed: _openHistory,
              ),
            if (_canManage)
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.share_outlined),
                onPressed: _page == null ? null : _openShare,
              ),
            if (_canEdit && !_isSop)
              IconButton(
                tooltip: 'Add subpage',
                icon: const Icon(Icons.add),
                onPressed: _page == null ? null : _addSubpage,
              ),
            if (_canEdit && !_isSop)
              IconButton(
                tooltip: 'Save as template',
                icon: const Icon(Icons.bookmark_add_outlined),
                onPressed: _page == null ? null : _saveAsTemplate,
              ),
            if (_canManage)
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
                        if (_incomingFrom != null)
                          _ReloadBanner(
                            name: _incomingFrom!,
                            onReload: () => _reloadBody(),
                            onDismiss: () =>
                                setState(() => _incomingFrom = null),
                          ),
                        _Breadcrumb(ancestors: _ancestors(), onTap: _openPage),
                        if (_page != null) _statusChips(scheme),
                        TextField(
                          controller: _title,
                          readOnly: !_canEdit,
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
                        if (_isSop && _canEdit) _sopBar(),
                        const Divider(),
                        Expanded(
                          child: _preview
                              ? SingleChildScrollView(
                                  child: MarkdownView(data: _body.text),
                                )
                              : TextField(
                                  controller: _body,
                                  readOnly: !_canEdit,
                                  onChanged: (_) =>
                                      setState(() => _dirty = true),
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  keyboardType: TextInputType.multiline,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: _canEdit
                                        ? 'Write in plain text or Markdown…'
                                        : null,
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

/// Shown when another user edits this page while you have unsaved changes.
class _ReloadBanner extends StatelessWidget {
  const _ReloadBanner({
    required this.name,
    required this.onReload,
    required this.onDismiss,
  });

  final String name;
  final VoidCallback onReload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.sync_problem_outlined,
            size: 18,
            color: AppColors.amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$name edited this page. Reloading will discard your unsaved '
              'changes.',
            ),
          ),
          TextButton(onPressed: onDismiss, child: const Text('Keep mine')),
          FilledButton(onPressed: onReload, child: const Text('Reload')),
        ],
      ),
    );
  }
}

/// A clickable ancestor trail shown above a nested doc's title.
class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.ancestors, required this.onTap});

  final List<WorkspacePage> ancestors;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (ancestors.isEmpty) {
      return const SizedBox.shrink();
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle style = TextStyle(
      fontSize: 12,
      color: scheme.onSurfaceVariant,
    );
    final List<Widget> parts = <Widget>[];
    for (int i = 0; i < ancestors.length; i++) {
      final WorkspacePage a = ancestors[i];
      parts.add(
        InkWell(
          onTap: () => onTap(a.id),
          child: Text(a.displayTitle, style: style),
        ),
      );
      if (i < ancestors.length - 1) {
        parts.add(Text('  /  ', style: style));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: parts,
      ),
    );
  }
}
