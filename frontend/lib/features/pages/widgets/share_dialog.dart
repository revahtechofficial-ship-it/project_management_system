import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/page_share.dart';
import '../../../data/models/team_member.dart';
import '../../../data/models/workspace_page.dart';
import '../../team/providers/team_providers.dart';
import '../providers/pages_providers.dart';

/// Opens the sharing/permissions dialog for [page] (author/admin only).
Future<void> showShareDialog(BuildContext context, WorkspacePage page) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => _ShareDialog(page: page),
  );
}

class _ShareDialog extends ConsumerStatefulWidget {
  const _ShareDialog({required this.page});

  final WorkspacePage page;

  @override
  ConsumerState<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends ConsumerState<_ShareDialog> {
  late String _visibility = widget.page.visibility;
  bool _busy = false;

  int get _id => widget.page.id;

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _setVisibility(String v) async {
    setState(() => _busy = true);
    try {
      await ref.read(pagesRepositoryProvider).setVisibility(_id, v);
      setState(() => _visibility = v);
    } catch (e) {
      _snack('Could not change visibility: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _share(int userId, String permission) async {
    setState(() => _busy = true);
    try {
      await ref.read(pagesRepositoryProvider).addShare(_id, userId, permission);
      ref.invalidate(pageSharesProvider(_id));
    } catch (e) {
      _snack('Could not update sharing: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove(int userId) async {
    setState(() => _busy = true);
    try {
      await ref.read(pagesRepositoryProvider).removeShare(_id, userId);
      ref.invalidate(pageSharesProvider(_id));
    } catch (e) {
      _snack('Could not remove access: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addPeople(List<PageShare> current) async {
    final Set<int> have = current.map((PageShare s) => s.userId).toSet();
    final List<TeamMember> candidates =
        (ref.read(teamMembersProvider).asData?.value ?? const <TeamMember>[])
            .where((TeamMember m) => !have.contains(m.id))
            .toList(growable: false);
    if (candidates.isEmpty) {
      _snack('Everyone already has access.');
      return;
    }
    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Add people'),
        children: <Widget>[
          for (final TeamMember m in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(
                  name: m.name.isEmpty ? m.email : m.name,
                  radius: 16,
                  imageUrl: m.avatarUrl,
                ),
                title: Text(m.name.isEmpty ? m.email : m.name),
              ),
            ),
        ],
      ),
    );
    if (picked != null) {
      await _share(picked, 'view');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isPrivate = _visibility == 'private';
    final AsyncValue<List<PageShare>> shares = ref.watch(
      pageSharesProvider(_id),
    );
    return AlertDialog(
      title: Text('Share "${widget.page.displayTitle}"'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'workspace',
                  icon: Icon(Icons.groups_outlined, size: 18),
                  label: Text('Everyone'),
                ),
                ButtonSegment<String>(
                  value: 'private',
                  icon: Icon(Icons.lock_outline, size: 18),
                  label: Text('Restricted'),
                ),
              ],
              selected: <String>{_visibility},
              showSelectedIcon: false,
              onSelectionChanged: _busy
                  ? null
                  : (Set<String> s) => _setVisibility(s.first),
            ),
            const SizedBox(height: 8),
            Text(
              isPrivate
                  ? 'Only the author and the people below can open this page.'
                  : 'Everyone in the workspace can view and edit this page.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (isPrivate) ...<Widget>[
              const Divider(height: 24),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'People with access',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () =>
                              _addPeople(shares.asData?.value ?? <PageShare>[]),
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: shares.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (Object e, _) => Text('Could not load: $e'),
                  data: (List<PageShare> people) => people.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Not shared with anyone yet.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: <Widget>[
                            for (final PageShare s in people)
                              _ShareTile(
                                share: s,
                                onPermission: (String p) => _share(s.userId, p),
                                onRemove: () => _remove(s.userId),
                              ),
                          ],
                        ),
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

class _ShareTile extends StatelessWidget {
  const _ShareTile({
    required this.share,
    required this.onPermission,
    required this.onRemove,
  });

  final PageShare share;
  final ValueChanged<String> onPermission;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String name = share.fullName.isEmpty ? share.email : share.fullName;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(name: name, radius: 16, imageUrl: share.avatarUrl),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DropdownButton<String>(
            value: share.permission == 'edit' ? 'edit' : 'view',
            underline: const SizedBox.shrink(),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'view', child: Text('Can view')),
              DropdownMenuItem<String>(value: 'edit', child: Text('Can edit')),
            ],
            onChanged: (String? v) {
              if (v != null) {
                onPermission(v);
              }
            },
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
