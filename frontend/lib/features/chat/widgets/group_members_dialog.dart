import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/chat_member.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/team_member.dart';
import '../../../providers/auth_provider.dart';
import '../../team/providers/team_providers.dart';
import '../providers/chat_providers.dart';

/// Opens the group info sheet for [conversation]: the member list, plus
/// add/remove controls for the group's admin (its creator) and a "leave"
/// action for everyone. Returns `true` if the current user left the group, so
/// the caller can close the open thread.
Future<bool> showGroupMembers(
  BuildContext context,
  Conversation conversation,
) async {
  final bool? left = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) =>
        _GroupMembersDialog(conversation: conversation),
  );
  return left ?? false;
}

class _GroupMembersDialog extends ConsumerStatefulWidget {
  const _GroupMembersDialog({required this.conversation});

  final Conversation conversation;

  @override
  ConsumerState<_GroupMembersDialog> createState() =>
      _GroupMembersDialogState();
}

class _GroupMembersDialogState extends ConsumerState<_GroupMembersDialog> {
  bool _busy = false;

  Conversation get _conv => widget.conversation;

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _addMembers(List<ChatMember> current) async {
    final Set<int> existing = current.map((ChatMember m) => m.userId).toSet();
    final List<TeamMember> candidates =
        (ref.read(teamMembersProvider).asData?.value ?? const <TeamMember>[])
            .where((TeamMember t) => !existing.contains(t.id))
            .toList(growable: false);
    if (candidates.isEmpty) {
      _snack('Everyone is already in this group.');
      return;
    }
    final List<int>? picked = await showDialog<List<int>>(
      context: context,
      builder: (BuildContext context) =>
          _AddMembersPicker(candidates: candidates),
    );
    if (picked == null || picked.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(chatRepositoryProvider).addMembers(_conv.id, picked);
      ref.invalidate(conversationMembersProvider(_conv.id));
      ref.invalidate(conversationsProvider);
    } catch (e) {
      _snack('Could not add members: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove(ChatMember m) async {
    final String name = m.fullName.isEmpty ? m.email : m.fullName;
    final bool ok = await _confirm(
      'Remove $name?',
      'They will lose access to this group and its messages.',
      'Remove',
    );
    if (!ok) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(chatRepositoryProvider).removeMember(_conv.id, m.userId);
      ref.invalidate(conversationMembersProvider(_conv.id));
      ref.invalidate(conversationsProvider);
    } catch (e) {
      _snack('Could not remove member: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Promotes a member to admin (`role` = 'admin') or demotes them ('member').
  Future<void> _setRole(ChatMember m, String role) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .setMemberRole(_conv.id, m.userId, role);
      ref.invalidate(conversationMembersProvider(_conv.id));
      ref.invalidate(conversationsProvider);
      final String name = m.fullName.isEmpty ? m.email : m.fullName;
      _snack(
        role == 'admin'
            ? '$name is now an admin'
            : '$name is no longer an admin',
      );
    } catch (e) {
      _snack('Could not update role: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _leave() async {
    final int? me = ref.read(authControllerProvider).asData?.value.user?.id;
    if (me == null) {
      return;
    }
    final List<ChatMember> members =
        ref.read(conversationMembersProvider(_conv.id)).asData?.value ??
        const <ChatMember>[];
    final int admins = members.where((ChatMember m) => m.isAdmin).length;
    final bool iAmAdmin = members.any(
      (ChatMember m) => m.userId == me && m.isAdmin,
    );
    if (iAmAdmin && admins <= 1 && members.length > 1) {
      _snack(
        'You are the only admin. Make someone else an admin before leaving.',
      );
      return;
    }
    final String label = _conv.name.isEmpty ? 'this group' : '"${_conv.name}"';
    final bool ok = await _confirm(
      'Leave $label?',
      'You will no longer receive messages from this group.',
      'Leave',
    );
    if (!ok) {
      return;
    }
    try {
      await ref.read(chatRepositoryProvider).removeMember(_conv.id, me);
      ref.invalidate(conversationsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _snack('Could not leave the group: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int? me = ref.watch(authControllerProvider).asData?.value.user?.id;
    final AsyncValue<List<ChatMember>> membersAsync = ref.watch(
      conversationMembersProvider(_conv.id),
    );
    final List<ChatMember> members =
        membersAsync.asData?.value ?? const <ChatMember>[];
    final bool iAmAdmin = members.any(
      (ChatMember m) => m.userId == me && m.isAdmin,
    );

    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.groups_2_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _conv.name.isEmpty ? 'Group' : _conv.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${members.length} '
                  '${members.length == 1 ? 'member' : 'members'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (iAmAdmin)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _addMembers(members),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add members'),
                ),
              ),
            if (membersAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final ChatMember m in members)
                      _MemberTile(
                        member: m,
                        isMe: m.userId == me,
                        showActions: iAmAdmin && m.userId != me && !_busy,
                        onMakeAdmin: () => _setRole(m, 'admin'),
                        onDismissAdmin: () => _setRole(m, 'member'),
                        onRemove: () => _remove(m),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : _leave,
          child: Text('Leave group', style: TextStyle(color: AppColors.rose)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// A single row in the member list, with a role badge and — for an admin
/// viewing another member — a menu to promote/demote or remove them.
class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.showActions,
    required this.onMakeAdmin,
    required this.onDismissAdmin,
    required this.onRemove,
  });

  final ChatMember member;
  final bool isMe;
  final bool showActions;
  final VoidCallback onMakeAdmin;
  final VoidCallback onDismissAdmin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String name = member.fullName.isEmpty
        ? member.email
        : member.fullName;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(name: name, radius: 18, imageUrl: member.avatarUrl),
      title: Text(
        isMe ? '$name (You)' : name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        member.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (member.isAdmin) const _RoleBadge(label: 'Admin'),
          if (showActions)
            PopupMenuButton<String>(
              tooltip: 'Manage member',
              icon: const Icon(Icons.more_vert),
              onSelected: (String value) {
                switch (value) {
                  case 'make_admin':
                    onMakeAdmin();
                  case 'dismiss_admin':
                    onDismissAdmin();
                  case 'remove':
                    onRemove();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (member.isAdmin)
                  const PopupMenuItem<String>(
                    value: 'dismiss_admin',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.remove_moderator_outlined),
                      title: Text('Dismiss as admin'),
                    ),
                  )
                else
                  const PopupMenuItem<String>(
                    value: 'make_admin',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.shield_outlined),
                      title: Text('Make admin'),
                    ),
                  ),
                const PopupMenuItem<String>(
                  value: 'remove',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.person_remove_outlined,
                      color: AppColors.rose,
                    ),
                    title: Text(
                      'Remove from group',
                      style: TextStyle(color: AppColors.rose),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.brand,
        ),
      ),
    );
  }
}

/// A checkbox picker of workspace members not yet in the group. Pops the list
/// of selected user ids, or null if cancelled.
class _AddMembersPicker extends StatefulWidget {
  const _AddMembersPicker({required this.candidates});

  final List<TeamMember> candidates;

  @override
  State<_AddMembersPicker> createState() => _AddMembersPickerState();
}

class _AddMembersPickerState extends State<_AddMembersPicker> {
  final Set<int> _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add members'),
      content: SizedBox(
        width: 360,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final TeamMember m in widget.candidates)
                CheckboxListTile(
                  value: _selected.contains(m.id),
                  title: Text(
                    m.name.isEmpty ? m.email : m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondary: UserAvatar(
                    name: m.name.isEmpty ? m.email : m.name,
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
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected.toList()),
          child: Text('Add (${_selected.length})'),
        ),
      ],
    );
  }
}
