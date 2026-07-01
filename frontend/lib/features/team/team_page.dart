import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/enums/member_role.dart';
import '../../data/models/team_member.dart';
import '../../providers/auth_provider.dart';
import 'providers/team_providers.dart';

enum _TeamView { directory, org }

/// The team directory: workspace members (registered users) with role and
/// real task workload from the backend, plus an org view grouped by
/// department.
class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({super.key});

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  _TeamView _view = _TeamView.directory;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TeamMember>> teamAsync =
        ref.watch(teamMembersProvider);
    final List<TeamMember> members =
        teamAsync.asData?.value ?? const <TeamMember>[];
    final int open =
        members.fold<int>(0, (int s, TeamMember m) => s + m.openTasks);
    final int done =
        members.fold<int>(0, (int s, TeamMember m) => s + m.completedTasks);
    final int rate =
        (open + done) == 0 ? 0 : ((done / (open + done)) * 100).round();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        PageHeader(
          title: 'Team',
          subtitle: 'Everyone in your Revah Tech workspace',
          actions: <Widget>[
            SegmentedButton<_TeamView>(
              segments: const <ButtonSegment<_TeamView>>[
                ButtonSegment<_TeamView>(
                  value: _TeamView.directory,
                  icon: Icon(Icons.badge_outlined, size: 18),
                  label: Text('Directory'),
                ),
                ButtonSegment<_TeamView>(
                  value: _TeamView.org,
                  icon: Icon(Icons.account_tree_outlined, size: 18),
                  label: Text('Org'),
                ),
              ],
              selected: <_TeamView>{_view},
              showSelectedIcon: false,
              onSelectionChanged: (Set<_TeamView> s) =>
                  setState(() => _view = s.first),
            ),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(teamMembersProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            FilledButton.icon(
              onPressed: () => _copyInvite(context),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Invite member'),
            ),
          ],
        ),
        if (teamAsync.isLoading) const LoadingBar(),
        if (teamAsync.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ErrorNotice(error: teamAsync.error!),
          ),
        const SizedBox(height: 20),
        StatCardGrid(
          cards: <Widget>[
            StatCard(
              icon: Icons.groups_rounded,
              color: AppColors.brand,
              label: 'Team members',
              value: '${members.length}',
              footer: 'registered users',
            ),
            StatCard(
              icon: Icons.timelapse_rounded,
              color: AppColors.orange,
              label: 'Open tasks',
              value: '$open',
              footer: 'assigned to the team',
            ),
            StatCard(
              icon: Icons.verified_rounded,
              color: AppColors.teal,
              label: 'Completed',
              value: '$done',
              footer: 'all-time',
            ),
            StatCard(
              icon: Icons.donut_large_rounded,
              color: AppColors.sky,
              label: 'Completion rate',
              value: '$rate%',
              progress: rate / 100,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (teamAsync.isLoading && members.isEmpty)
          const SkeletonTiles(count: 6)
        else if (members.isEmpty)
          const EmptyState(
            icon: Icons.group_off_rounded,
            message: 'No members yet.',
          )
        else if (_view == _TeamView.org)
          _OrgChart(members: members)
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double w = constraints.maxWidth;
              final int cols = w >= 1080 ? 3 : (w >= 680 ? 2 : 1);
              const double gap = 16;
              final double cardW = (w - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: <Widget>[
                  for (final TeamMember member in members)
                    SizedBox(
                        width: cardW, child: _MemberCard(member: member)),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<void> _copyInvite(BuildContext context) async {
    final String link = '${Uri.base.origin}/signup';
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) {
      return;
    }
    context.showSuccess('Invite link copied: $link');
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({required this.member});
  final TeamMember member;

  Future<void> _setRole(
      BuildContext context, WidgetRef ref, MemberRole role) async {
    try {
      await ref.read(teamRepositoryProvider).setRole(member.id, role);
      ref.invalidate(teamMembersProvider);
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not change role: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool canManage =
        (ref.watch(authControllerProvider).asData?.value.isAdmin ?? false) &&
            member.role != MemberRole.owner;

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              UserAvatar(
                  name: member.name, radius: 24, imageUrl: member.avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(member.name.isEmpty ? member.email : member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(member.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<MemberRole>(
                  tooltip: 'Change role',
                  icon: Icon(Icons.more_vert,
                      size: 20, color: scheme.onSurfaceVariant),
                  onSelected: (MemberRole r) => _setRole(context, ref, r),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<MemberRole>>[
                    for (final MemberRole r in MemberRole.assignable)
                      if (r != member.role)
                        PopupMenuItem<MemberRole>(
                          value: r,
                          child: Text('Make ${r.label.toLowerCase()}'),
                        ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              StatusPill(label: member.role.label, color: member.role.color),
              const Spacer(),
              Text('Joined ${shortDate(member.createdAt)}',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _MiniStat(value: '${member.openTasks}', label: 'Open'),
              const SizedBox(width: 8),
              _MiniStat(value: '${member.completedTasks}', label: 'Done'),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: member.progress,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: member.role.color,
            ),
          ),
          const SizedBox(height: 6),
          Text('${(member.progress * 100).round()}% completed',
              style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Members grouped by department — a lightweight org view. (A true reporting
/// tree would need a manager relationship on users, which isn't modelled yet.)
class _OrgChart extends StatelessWidget {
  const _OrgChart({required this.members});
  final List<TeamMember> members;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<TeamMember>> byDept = <String, List<TeamMember>>{};
    for (final TeamMember m in members) {
      final String dept =
          m.department.trim().isEmpty ? 'Unassigned' : m.department.trim();
      byDept.putIfAbsent(dept, () => <TeamMember>[]).add(m);
    }
    final List<String> depts = byDept.keys.toList()
      ..sort((String a, String b) {
        if (a == 'Unassigned') return 1;
        if (b == 'Unassigned') return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int cols = c.maxWidth >= 1080 ? 3 : (c.maxWidth >= 680 ? 2 : 1);
        const double gap = 16;
        final double cardW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final String dept in depts)
              SizedBox(
                width: cardW,
                child: _OrgDeptCard(
                  department: dept,
                  members: byDept[dept]!
                    ..sort((TeamMember a, TeamMember b) =>
                        a.role.index.compareTo(b.role.index)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrgDeptCard extends StatelessWidget {
  const _OrgDeptCard({required this.department, required this.members});
  final String department;
  final List<TeamMember> members;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.apartment_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  department,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Text('${members.length}',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(height: 20),
          for (final TeamMember m in members) _OrgMemberRow(member: m),
        ],
      ),
    );
  }
}

class _OrgMemberRow extends StatelessWidget {
  const _OrgMemberRow({required this.member});
  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String subtitle = member.jobTitle.trim().isNotEmpty
        ? member.jobTitle
        : member.role.label;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          UserAvatar(name: member.name, radius: 16, imageUrl: member.avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  member.name.isEmpty ? member.email : member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (member.role == MemberRole.owner || member.role == MemberRole.admin)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: StatusPill(
                  label: member.role.label, color: member.role.color),
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: <Widget>[
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
