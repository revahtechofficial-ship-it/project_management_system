import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/project_member.dart';
import '../../../data/models/team_member.dart';
import '../../team/providers/team_providers.dart';
import '../providers/projects_providers.dart';

/// The per-project roles a member can hold.
const List<(String, String)> kProjectRoles = <(String, String)>[
  ('viewer', 'Viewer'),
  ('editor', 'Editor'),
  ('manager', 'Manager'),
];

/// Opens the members & roles dialog for a project.
Future<void> showProjectMembersDialog(
  BuildContext context,
  int projectId,
  String projectName,
) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext _) =>
        _ProjectMembersDialog(projectId: projectId, projectName: projectName),
  );
}

class _ProjectMembersDialog extends ConsumerWidget {
  const _ProjectMembersDialog({
    required this.projectId,
    required this.projectName,
  });

  final int projectId;
  final String projectName;

  void _refresh(WidgetRef ref) =>
      ref.invalidate(projectMembersProvider(projectId));

  Future<void> _setRole(
      BuildContext context, WidgetRef ref, int userId, String role) async {
    try {
      await ref
          .read(projectsRepositoryProvider)
          .setMember(projectId, userId, role);
      _refresh(ref);
      ref.invalidate(projectsProvider);
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not update: $e');
      }
    }
  }

  Future<void> _remove(
      BuildContext context, WidgetRef ref, int userId) async {
    try {
      await ref.read(projectsRepositoryProvider).removeMember(projectId, userId);
      _refresh(ref);
      ref.invalidate(projectsProvider);
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not remove: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<ProjectMembership> async =
        ref.watch(projectMembersProvider(projectId));
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
                  const Icon(Icons.manage_accounts_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Members · $projectName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
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
                data: (ProjectMembership m) => _Body(
                  membership: m,
                  scheme: scheme,
                  onSetRole: (int uid, String role) =>
                      _setRole(context, ref, uid, role),
                  onRemove: (int uid) => _remove(context, ref, uid),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.membership,
    required this.scheme,
    required this.onSetRole,
    required this.onRemove,
  });

  final ProjectMembership membership;
  final ColorScheme scheme;
  final void Function(int userId, String role) onSetRole;
  final void Function(int userId) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canManage = membership.canManage;
    final Set<int> existing =
        membership.members.map((ProjectMember m) => m.userId).toSet();
    final List<TeamMember> addable =
        (ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[])
            .where((TeamMember t) => !existing.contains(t.id))
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            membership.members.isEmpty
                ? 'This project has no members yet, so everyone in the '
                    'workspace can manage it. Add a member to start '
                    'restricting access.'
                : 'Only these members can edit the project; everyone else can '
                    'view it. Workspace admins always manage.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          if (membership.members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No members yet.',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          else
            for (final ProjectMember m in membership.members)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    UserAvatar(name: m.displayName, radius: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(m.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          if (m.userEmail.isNotEmpty)
                            Text(m.userEmail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<String>(
                        initialValue: m.role,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        items: <DropdownMenuItem<String>>[
                          for (final (String key, String label) in kProjectRoles)
                            DropdownMenuItem<String>(
                                value: key, child: Text(label)),
                        ],
                        onChanged: canManage
                            ? (String? v) {
                                if (v != null) {
                                  onSetRole(m.userId, v);
                                }
                              }
                            : null,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed:
                          canManage ? () => onRemove(m.userId) : null,
                    ),
                  ],
                ),
              ),
          if (canManage) ...<Widget>[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 6),
            Text('Add a member',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            _AddMemberRow(
              candidates: addable,
              onAdd: onSetRole,
            ),
          ],
        ],
      ),
    );
  }
}

class _AddMemberRow extends StatefulWidget {
  const _AddMemberRow({required this.candidates, required this.onAdd});

  final List<TeamMember> candidates;
  final void Function(int userId, String role) onAdd;

  @override
  State<_AddMemberRow> createState() => _AddMemberRowState();
}

class _AddMemberRowState extends State<_AddMemberRow> {
  int? _userId;
  String _role = 'editor';

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty) {
      return Text('Everyone is already a member.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _userId,
            isExpanded: true,
            decoration: const InputDecoration(
                isDense: true, labelText: 'Team member'),
            items: <DropdownMenuItem<int>>[
              for (final TeamMember t in widget.candidates)
                DropdownMenuItem<int>(
                  value: t.id,
                  child: Text(t.name.isEmpty ? t.email : t.name,
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (int? v) => setState(() => _userId = v),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<String>(
            initialValue: _role,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: <DropdownMenuItem<String>>[
              for (final (String key, String label) in kProjectRoles)
                DropdownMenuItem<String>(value: key, child: Text(label)),
            ],
            onChanged: (String? v) => setState(() => _role = v ?? _role),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _userId == null
              ? null
              : () {
                  widget.onAdd(_userId!, _role);
                  setState(() => _userId = null);
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
