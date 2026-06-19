import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/enums/page_type.dart';
import '../../../data/models/team_member.dart';
import '../../../data/models/workspace_page.dart';
import '../../team/providers/team_providers.dart';
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
  final TextEditingController _category = TextEditingController();
  WorkspacePage? _page;
  int? _ownerId;
  DateTime? _reviewAt;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  bool get _isSop => _page?.type == PageType.sop;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved as template')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save template: $e')));
      }
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add subpage: $e')));
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
            if (!_isSop)
              IconButton(
                tooltip: 'Add subpage',
                icon: const Icon(Icons.add),
                onPressed: _page == null ? null : _addSubpage,
              ),
            if (!_isSop)
              IconButton(
                tooltip: 'Save as template',
                icon: const Icon(Icons.bookmark_add_outlined),
                onPressed: _page == null ? null : _saveAsTemplate,
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
                        _Breadcrumb(ancestors: _ancestors(), onTap: _openPage),
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
                        if (_isSop) _sopBar(),
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
