import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/enums/member_role.dart';
import '../../data/models/admin_member.dart';
import '../../data/models/audit_event.dart';
import '../../data/models/workspace_settings.dart';
import '../../providers/auth_provider.dart';
import 'providers/admin_providers.dart';

/// The admin console: member access management (roles, guest access,
/// activation), the security audit log, and workspace security settings
/// (AGENTS.md §1 feature page).
class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  _Tab _tab = _Tab.members;

  @override
  Widget build(BuildContext context) {
    final bool isAdmin =
        ref.watch(authControllerProvider).asData?.value.isAdmin ?? false;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Administration',
            subtitle: 'Access management, audit log and security',
            actions: <Widget>[
              if (isAdmin)
                SegmentedButton<_Tab>(
                  segments: const <ButtonSegment<_Tab>>[
                    ButtonSegment<_Tab>(
                      value: _Tab.members,
                      icon: Icon(Icons.manage_accounts_outlined, size: 18),
                      label: Text('Members'),
                    ),
                    ButtonSegment<_Tab>(
                      value: _Tab.audit,
                      icon: Icon(Icons.fact_check_outlined, size: 18),
                      label: Text('Audit log'),
                    ),
                    ButtonSegment<_Tab>(
                      value: _Tab.security,
                      icon: Icon(Icons.security_outlined, size: 18),
                      label: Text('Security'),
                    ),
                  ],
                  selected: <_Tab>{_tab},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<_Tab> s) =>
                      setState(() => _tab = s.first),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: !isAdmin
                ? const EmptyState(
                    icon: Icons.lock_outline,
                    message: 'Administrator access is required for this area.',
                  )
                : switch (_tab) {
                    _Tab.members => const _MembersView(),
                    _Tab.audit => const _AuditView(),
                    _Tab.security => const _SecurityView(),
                  },
          ),
        ],
      ),
    );
  }
}

enum _Tab { members, audit, security }

// --- Members ---------------------------------------------------------------

class _MembersView extends ConsumerWidget {
  const _MembersView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminMember>> async = ref.watch(adminMembersProvider);
    final int? meId = ref.watch(authControllerProvider).asData?.value.user?.id;
    return async.when(
      loading: () => const LoadingView(),
      error: (Object e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(adminMembersProvider),
      ),
      data: (List<AdminMember> members) => ListView.separated(
        itemCount: members.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int i) =>
            _MemberRow(member: members[i], isSelf: members[i].id == meId),
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.member, required this.isSelf});

  final AdminMember member;
  final bool isSelf;

  Future<void> _setRole(WidgetRef ref, MemberRole role) async {
    await ref.read(adminRepositoryProvider).setRole(member.id, role.toJson());
    ref.invalidate(adminMembersProvider);
    ref.invalidate(auditLogProvider);
  }

  Future<void> _setActive(WidgetRef ref, bool active) async {
    await ref.read(adminRepositoryProvider).setActive(member.id, active);
    ref.invalidate(adminMembersProvider);
    ref.invalidate(auditLogProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isOwner = member.role == MemberRole.owner;
    final bool locked = isOwner || isSelf;
    return DashboardCard(
      child: Row(
        children: <Widget>[
          UserAvatar(
            name: member.displayName,
            radius: 18,
            imageUrl: member.avatarUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (member.twoFactorEnabled) ...<Widget>[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: '2FA enabled',
                        child: Icon(
                          Icons.verified_user,
                          size: 15,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                    if (!member.isActive) ...<Widget>[
                      const SizedBox(width: 6),
                      _Pill(label: 'Disabled', color: AppColors.rose),
                    ],
                  ],
                ),
                Text(
                  member.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isOwner)
            _Pill(label: 'Owner', color: AppColors.amber)
          else
            DropdownButton<MemberRole>(
              value: member.role,
              underline: const SizedBox.shrink(),
              onChanged: locked
                  ? null
                  : (MemberRole? r) {
                      if (r != null) {
                        _setRole(ref, r);
                      }
                    },
              items: <DropdownMenuItem<MemberRole>>[
                for (final MemberRole r in MemberRole.assignable)
                  DropdownMenuItem<MemberRole>(
                    value: r,
                    child: Text(r.label),
                  ),
              ],
            ),
          const SizedBox(width: 12),
          Tooltip(
            message: member.isActive ? 'Active' : 'Deactivated',
            child: Switch(
              value: member.isActive,
              onChanged: locked ? null : (bool v) => _setActive(ref, v),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Audit log -------------------------------------------------------------

class _AuditView extends ConsumerWidget {
  const _AuditView();

  static (IconData, Color) _visual(String action) {
    if (action.startsWith('role')) {
      return (Icons.badge_outlined, AppColors.violet);
    }
    if (action.startsWith('user.deactiv')) {
      return (Icons.person_off_outlined, AppColors.rose);
    }
    if (action.startsWith('user')) {
      return (Icons.person_outline, AppColors.green);
    }
    if (action.startsWith('integration')) {
      return (Icons.extension_outlined, AppColors.sky);
    }
    if (action.startsWith('apikey')) {
      return (Icons.key_outlined, AppColors.orange);
    }
    if (action.startsWith('settings')) {
      return (Icons.tune_outlined, AppColors.slate);
    }
    return (Icons.history, AppColors.slate);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<AuditEvent>> async = ref.watch(auditLogProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (Object e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(auditLogProvider),
      ),
      data: (List<AuditEvent> events) {
        if (events.isEmpty) {
          return const EmptyState(
            icon: Icons.fact_check_outlined,
            message: 'No audit events recorded yet.',
          );
        }
        return ListView.separated(
          itemCount: events.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (BuildContext context, int i) {
            final AuditEvent e = events[i];
            final (IconData icon, Color color) = _visual(e.action);
            return ListTile(
              leading: Icon(icon, color: color),
              title: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: e.actorName.isEmpty ? 'Someone' : e.actorName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: '  ${e.action}'),
                    if (e.target.isNotEmpty)
                      TextSpan(
                        text: '  ${e.target}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              subtitle: e.detail.isEmpty ? null : Text(e.detail),
              trailing: Text(
                relativeTime(e.createdAt),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            );
          },
        );
      },
    );
  }
}

// --- Security settings -----------------------------------------------------

class _SecurityView extends ConsumerStatefulWidget {
  const _SecurityView();

  @override
  ConsumerState<_SecurityView> createState() => _SecurityViewState();
}

class _SecurityViewState extends ConsumerState<_SecurityView> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _domains = TextEditingController();
  final TextEditingController _session = TextEditingController();
  bool _require2fa = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _domains.dispose();
    _session.dispose();
    super.dispose();
  }

  void _seed(WorkspaceSettings s) {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _name.text = s.name;
    _domains.text = s.allowedDomains;
    _session.text = '${s.sessionHours}';
    _require2fa = s.require2fa;
  }

  Future<void> _save(WorkspaceSettings current) async {
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).updateSettings(
            current.copyWith(
              name: _name.text.trim(),
              allowedDomains: _domains.text.trim(),
              require2fa: _require2fa,
              sessionHours: int.tryParse(_session.text.trim()) ?? 24,
            ),
          );
      ref.invalidate(workspaceSettingsProvider);
      ref.invalidate(auditLogProvider);
      if (mounted) {
        context.showSuccess('Settings saved');
      }
    } catch (e) {
      if (mounted) {
        context.showError('Could not save: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<WorkspaceSettings> async = ref.watch(
      workspaceSettingsProvider,
    );
    return async.when(
      loading: () => const LoadingView(),
      error: (Object e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(workspaceSettingsProvider),
      ),
      data: (WorkspaceSettings s) {
        _seed(s);
        return ListView(
          children: <Widget>[
            DashboardCard(
              title: 'Workspace',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Workspace name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _domains,
                    decoration: const InputDecoration(
                      labelText: 'Allowed sign-up domains',
                      helperText:
                          'Comma-separated, e.g. revah.tech, acme.com. '
                          'Empty allows any domain.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DashboardCard(
              title: 'Security controls',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.shield_outlined),
                    title: const Text('Require two-factor authentication'),
                    subtitle: const Text(
                      'Recommend all members enable email 2FA.',
                    ),
                    value: _require2fa,
                    onChanged: (bool v) => setState(() => _require2fa = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _session,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Session length (hours)',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DashboardCard(
              title: 'Single Sign-On',
              child: Row(
                children: <Widget>[
                  Icon(
                    s.ssoConfigured ? Icons.check_circle : Icons.cancel_outlined,
                    color: s.ssoConfigured ? AppColors.green : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.ssoConfigured
                          ? 'SSO is configured via Keycloak (OIDC). Members can '
                                'authenticate through your identity provider.'
                          : 'SSO is not configured. Set an OIDC issuer to enable '
                                'Keycloak single sign-on.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _save(s),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- shared ----------------------------------------------------------------

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
