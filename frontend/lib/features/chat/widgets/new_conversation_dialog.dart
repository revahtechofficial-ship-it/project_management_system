import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/team_member.dart';
import '../../../providers/auth_provider.dart';
import '../../team/providers/team_providers.dart';
import '../providers/chat_providers.dart';

/// Picks a workspace member and opens (or reuses) a direct message with them.
/// Returns the conversation id, or null if cancelled.
Future<int?> startDirectMessage(BuildContext context, WidgetRef ref) {
  return showDialog<int>(
    context: context,
    builder: (BuildContext context) => const _DirectMessageDialog(),
  );
}

/// Creates a group conversation. Returns the new conversation id, or null.
Future<int?> createGroupChat(BuildContext context, WidgetRef ref) {
  return showDialog<int>(
    context: context,
    builder: (BuildContext context) => const _GroupDialog(),
  );
}

class _DirectMessageDialog extends ConsumerWidget {
  const _DirectMessageDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? me = ref.watch(authControllerProvider).asData?.value.user?.id;
    final List<TeamMember> members =
        ref
            .watch(teamMembersProvider)
            .asData
            ?.value
            .where((TeamMember m) => m.id != me)
            .toList() ??
        const <TeamMember>[];
    return AlertDialog(
      title: const Text('New message'),
      content: SizedBox(
        width: 360,
        child: members.isEmpty
            ? const Text('No other members yet.')
            : ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final TeamMember m in members)
                    ListTile(
                      leading: UserAvatar(
                        name: m.name,
                        radius: 18,
                        imageUrl: m.avatarUrl,
                      ),
                      title: Text(m.name),
                      subtitle: Text(
                        m.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        final int id = await ref
                            .read(chatRepositoryProvider)
                            .createDm(m.id);
                        if (context.mounted) {
                          Navigator.of(context).pop(id);
                        }
                      },
                    ),
                ],
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _GroupDialog extends ConsumerStatefulWidget {
  const _GroupDialog();

  @override
  ConsumerState<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends ConsumerState<_GroupDialog> {
  final TextEditingController _name = TextEditingController();
  final Set<int> _selected = <int>{};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final String name = _name.text.trim();
    if (name.isEmpty || _selected.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      final int id = await ref
          .read(chatRepositoryProvider)
          .createGroup(name, _selected.toList());
      if (mounted) {
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not create group: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? me = ref.watch(authControllerProvider).asData?.value.user?.id;
    final List<TeamMember> members =
        ref
            .watch(teamMembersProvider)
            .asData
            ?.value
            .where((TeamMember m) => m.id != me)
            .toList() ??
        const <TeamMember>[];
    return AlertDialog(
      title: const Text('New group'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Group name',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add members',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: members.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No other members yet.'),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final TeamMember m in members)
                          CheckboxListTile(
                            value: _selected.contains(m.id),
                            title: Text(m.name),
                            secondary: UserAvatar(
                              name: m.name,
                              radius: 16,
                              imageUrl: m.avatarUrl,
                            ),
                            onChanged: (bool? v) => setState(() {
                              if (v ?? false) {
                                _selected.add(m.id);
                              } else {
                                _selected.remove(m.id);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: Text(_saving ? 'Creating…' : 'Create'),
        ),
      ],
    );
  }
}
