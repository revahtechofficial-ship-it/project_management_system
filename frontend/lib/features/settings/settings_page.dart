import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/avatar_crop_dialog.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/enums/custom_field_type.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/custom_field.dart';
import '../../data/models/project_template.dart';
import '../../data/models/task_template.dart';
import '../../data/models/workflow_status.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../calendar/providers/calendar_providers.dart';
import '../projects/providers/project_templates_providers.dart';
import '../tasks/providers/custom_fields_providers.dart';
import '../tasks/providers/statuses_providers.dart';
import '../tasks/providers/task_templates_providers.dart';
import 'providers/settings_providers.dart';
import 'widgets/accent_picker_dialog.dart';
import 'widgets/change_password_dialog.dart';
import 'widgets/custom_field_dialog.dart';

/// Account and preference management. The theme selector and notification
/// switches are fully wired and persisted.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthUser? user = ref.watch(authControllerProvider).asData?.value.user;
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final SettingsState settings = ref.watch(settingsControllerProvider);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const PageHeader(
              title: 'Settings',
              subtitle: 'Manage your account and preferences',
            ),
            const SizedBox(height: 20),
            _ProfileCard(user: user),
            const SizedBox(height: 16),
            _AppearanceCard(themeMode: themeMode, settings: settings),
            const SizedBox(height: 16),
            _NotificationsCard(settings: settings),
            const SizedBox(height: 16),
            const _CalendarFeedCard(),
            const SizedBox(height: 16),
            const _TaskTemplatesCard(),
            const SizedBox(height: 16),
            const _ProjectTemplatesCard(),
            if (user?.isAdmin ?? false) ...<Widget>[
              const SizedBox(height: 16),
              const _StatusesCard(),
              const SizedBox(height: 16),
              const _CustomFieldsCard(),
            ],
            const SizedBox(height: 16),
            const _SecurityCard(),
            const SizedBox(height: 16),
            const _AboutCard(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rose,
                side: const BorderSide(color: AppColors.rose),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.user});
  final AuthUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String name = user?.name ?? 'User';
    return DashboardCard(
      child: Row(
        children: <Widget>[
          InkWell(
            onTap: () => _uploadPhoto(context, ref),
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: <Widget>[
                UserAvatar(name: name, radius: 28, imageUrl: user?.avatarUrl),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.brand,
                    child: const Icon(
                      Icons.camera_alt,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => context.push('/profile'),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadPhoto(BuildContext context, WidgetRef ref) async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.first.bytes;
    if (result == null || bytes == null || !context.mounted) {
      return;
    }
    final cropped = await cropAvatar(context, bytes);
    if (cropped == null) {
      return;
    }
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateAvatar(cropped, 'avatar.png');
      if (context.mounted) {
        context.showSuccess('Photo updated');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Upload failed: $e');
      }
    }
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard({required this.themeMode, required this.settings});

  final ThemeMode themeMode;
  final SettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsController c = ref.read(settingsControllerProvider.notifier);
    final bool isCustom = !AppColors.accentPresets
        .any((({String name, Color color}) p) =>
            p.color.toARGB32() == settings.accent);

    return DashboardCard(
      title: 'Appearance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _label(context, 'Accent color'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final ({String name, Color color}) preset
                  in AppColors.accentPresets)
                _AccentDot(
                  color: preset.color,
                  selected: preset.color.toARGB32() == settings.accent,
                  onTap: () => c.setAccent(preset.color.toARGB32()),
                ),
              _AccentDot(
                color: Color(settings.accent),
                selected: isCustom,
                icon: Icons.tune,
                onTap: () => showAccentPicker(
                  context,
                  ref,
                  Color(settings.accent),
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          _label(context, 'Theme'),
          const SizedBox(height: 10),
          Opacity(
            opacity: settings.autoDark ? 0.5 : 1,
            child: IgnorePointer(
              ignoring: settings.autoDark,
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: <ThemeMode>{themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<ThemeMode> selection) => ref
                      .read(themeModeProvider.notifier)
                      .setMode(selection.first),
                ),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto dark mode'),
            subtitle: const Text('Switch to dark in the evening (7 PM–7 AM)'),
            value: settings.autoDark,
            onChanged: c.setAutoDark,
          ),
          const Divider(height: 28),
          _label(context, 'Density'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Comfortable'),
                  icon: Icon(Icons.density_medium),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Compact'),
                  icon: Icon(Icons.density_small),
                ),
              ],
              selected: <bool>{settings.compactMode},
              showSelectedIcon: false,
              onSelectionChanged: (Set<bool> s) => c.setCompactMode(s.first),
            ),
          ),
          const Divider(height: 28),
          _label(context, 'Text size'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<double>(
              segments: const <ButtonSegment<double>>[
                ButtonSegment<double>(value: 0.9, label: Text('Small')),
                ButtonSegment<double>(value: 1.0, label: Text('Default')),
                ButtonSegment<double>(value: 1.15, label: Text('Large')),
                ButtonSegment<double>(value: 1.3, label: Text('Larger')),
              ],
              selected: <double>{settings.textScale},
              showSelectedIcon: false,
              onSelectionChanged: (Set<double> s) => c.setTextScale(s.first),
            ),
          ),
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce motion'),
            subtitle: const Text('Minimise animations and transitions'),
            value: settings.reduceMotion,
            onChanged: c.setReduceMotion,
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}

/// A tappable accent swatch used in the Appearance card.
class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: icon != null
            ? Icon(icon, color: Colors.white, size: 18)
            : (selected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null),
      ),
    );
  }
}

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard({required this.settings});
  final SettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsController c = ref.read(settingsControllerProvider.notifier);
    // Email notifications are a server-side per-user preference (they drive
    // actual outbound email), so this switch reflects the account, not the
    // local-only settings.
    final bool emailOn = ref
            .watch(authControllerProvider)
            .asData
            ?.value
            .user
            ?.emailNotifications ??
        true;
    return DashboardCard(
      title: 'Notifications',
      child: Column(
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Email notifications'),
            subtitle: const Text('Get your notifications by email too'),
            value: emailOn,
            onChanged: (bool v) =>
                ref.read(authControllerProvider.notifier)
                    .setEmailNotifications(v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Push notifications'),
            subtitle: const Text('In-app and browser alerts'),
            value: settings.pushNotifications,
            onChanged: c.setPushNotifications,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Weekly digest'),
            subtitle: const Text('A Monday summary of activity'),
            value: settings.weeklyDigest,
            onChanged: c.setWeeklyDigest,
          ),
        ],
      ),
    );
  }
}

/// A read-only iCalendar feed of your due tasks, to subscribe to in Google,
/// Outlook or Apple Calendar (one-way sync via an unguessable token URL).
class _CalendarFeedCard extends ConsumerWidget {
  const _CalendarFeedCard();

  String _feedUrl(String token) => '${AppConfig.apiBaseUrl}/api/v1/ics/$token';

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(calendarRepositoryProvider).rotate();
      ref.invalidate(calendarTokenProvider);
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not enable: $e');
      }
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(calendarRepositoryProvider).revoke();
      ref.invalidate(calendarTokenProvider);
      if (context.mounted) {
        context.showSuccess('Calendar feed disabled');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not disable: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String token = ref.watch(calendarTokenProvider).asData?.value ?? '';
    return DashboardCard(
      title: 'Calendar feed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Subscribe to your due tasks in Google, Outlook or Apple '
            'Calendar. The link is private — anyone with it can see your '
            'tasks, so keep it to yourself.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (token.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _enable(context, ref),
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: const Text('Enable calendar feed'),
              ),
            )
          else ...<Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _feedUrl(token),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy feed URL',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: _feedUrl(token)));
                      if (context.mounted) {
                        context.showSuccess('Feed URL copied');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => _enable(context, ref),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Regenerate'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _revoke(context, ref),
                  child: Text('Disable',
                      style: TextStyle(color: scheme.error)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Admin-only management of workspace custom fields for tasks.
class _CustomFieldsCard extends ConsumerWidget {
  const _CustomFieldsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<CustomField> fields =
        ref.watch(customFieldsProvider).asData?.value ?? const <CustomField>[];
    return DashboardCard(
      title: 'Custom fields',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Add fields that appear on every task.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No custom fields yet.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          for (final CustomField f in fields)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(f.type.icon, color: scheme.onSurfaceVariant),
              title: Text(f.name),
              subtitle: Text(
                f.type == CustomFieldType.select
                    ? 'Dropdown · ${f.options.join(', ')}'
                    : f.type.label,
              ),
              trailing: IconButton(
                tooltip: 'Delete field',
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: () => _delete(context, ref, f),
              ),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => showCustomFieldDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add field'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CustomField f,
  ) async {
    final bool ok = await confirmDelete(
      context,
      what: '"${f.name}"',
      message: 'This removes the field and its values from every task.',
    );
    if (!ok) {
      return;
    }
    await ref.read(customFieldsRepositoryProvider).delete(f.id);
    ref.invalidate(customFieldsProvider);
  }
}

class _SecurityCard extends ConsumerWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool twoFactor = ref
            .watch(authControllerProvider)
            .asData
            ?.value
            .user
            ?.twoFactorEnabled ??
        false;
    return DashboardCard(
      title: 'Security',
      child: Column(
        children: <Widget>[
          _SettingTile(
            icon: Icons.lock_outline,
            title: 'Change password',
            subtitle: 'Update your account password',
            onTap: () => _changePassword(context),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.shield_outlined),
            title: const Text('Two-factor authentication'),
            subtitle: const Text(
              'Email a verification code at each sign-in',
            ),
            value: twoFactor,
            onChanged: (bool v) => _setTwoFactor(context, ref, v),
          ),
        ],
      ),
    );
  }

  Future<void> _setTwoFactor(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    try {
      await ref.read(authControllerProvider.notifier).setTwoFactor(enabled);
      if (context.mounted) {
        context.showSuccess(
          enabled
              ? 'Two-factor authentication enabled'
              : 'Two-factor authentication disabled',
        );
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not update 2FA: $e');
      }
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const ChangePasswordDialog(),
    );
    if ((ok ?? false) && context.mounted) {
      context.showSuccess('Password updated successfully');
    }
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return const DashboardCard(
      title: 'About',
      child: Column(
        children: <Widget>[
          _AboutRow(label: 'Application', value: 'Revah Management System'),
          _AboutRow(label: 'Version', value: '1.0.0'),
          _AboutRow(label: 'Organisation', value: 'Revah Tech'),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Lists saved task templates with delete. Templates are created from any task
/// via the form's "Save as template" and used via "From template" on Tasks.
class _TaskTemplatesCard extends ConsumerWidget {
  const _TaskTemplatesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<TaskTemplate> templates =
        ref.watch(taskTemplatesProvider).asData?.value ??
        const <TaskTemplate>[];
    return DashboardCard(
      title: 'Task templates',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Reusable task blueprints. Save one from any task via "Save as '
            'template", then pick it from "From template" on the Tasks page.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (templates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No templates yet.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          for (final TaskTemplate t in templates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.bookmark_outline,
                color: scheme.onSurfaceVariant,
              ),
              title: Text(t.name),
              subtitle: t.title.isEmpty
                  ? null
                  : Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: 'Delete template',
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: () => _delete(context, ref, t),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TaskTemplate t,
  ) async {
    final bool ok = await confirmDelete(
      context,
      what: '"${t.name}"',
      message: 'This removes the template. Existing tasks are unaffected.',
    );
    if (!ok) {
      return;
    }
    await ref.read(taskTemplatesRepositoryProvider).delete(t.id);
    ref.invalidate(taskTemplatesProvider);
  }
}

/// Lists saved project templates with delete. Created from a project via the
/// project form's "Save as template", used from "From template" on Projects.
class _ProjectTemplatesCard extends ConsumerWidget {
  const _ProjectTemplatesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<ProjectTemplate> templates =
        ref.watch(projectTemplatesProvider).asData?.value ??
        const <ProjectTemplate>[];
    return DashboardCard(
      title: 'Project templates',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Reusable project blueprints. Save one from any project, then '
            'pick it from "From template" on the Projects page.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (templates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No templates yet.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          for (final ProjectTemplate t in templates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.bookmark_outline,
                color: scheme.onSurfaceVariant,
              ),
              title: Text(t.name),
              subtitle: t.projectName.isEmpty
                  ? null
                  : Text(
                      t.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: IconButton(
                tooltip: 'Delete template',
                icon: Icon(Icons.delete_outline, color: scheme.error),
                onPressed: () => _delete(context, ref, t),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ProjectTemplate t,
  ) async {
    final bool ok = await confirmDelete(
      context,
      what: '"${t.name}"',
      message: 'This removes the template. Existing projects are unaffected.',
    );
    if (!ok) {
      return;
    }
    await ref.read(projectTemplatesRepositoryProvider).delete(t.id);
    ref.invalidate(projectTemplatesProvider);
  }
}

/// Admin-only management of the workspace's task workflow statuses (board
/// columns): add / rename / recolor / reorder / delete, plus apply a template.
class _StatusesCard extends ConsumerWidget {
  const _StatusesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<WorkflowStatus> statuses =
        ref.watch(statusesProvider).asData?.value ?? const <WorkflowStatus>[];

    Future<void> move(int index, int delta) async {
      final int target = index + delta;
      if (target < 0 || target >= statuses.length) {
        return;
      }
      final List<int> ids = statuses.map((WorkflowStatus s) => s.id).toList();
      final int id = ids.removeAt(index);
      ids.insert(target, id);
      await ref.read(statusesRepositoryProvider).reorder(ids);
      ref.invalidate(statusesProvider);
    }

    return DashboardCard(
      title: 'Task statuses',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Customize the workflow columns shown on the board.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < statuses.length; i++)
            _StatusRow(
              status: statuses[i],
              canMoveUp: i > 0,
              canMoveDown: i < statuses.length - 1,
              onMoveUp: () => move(i, -1),
              onMoveDown: () => move(i, 1),
              onEdit: () => _showStatusDialog(context, statuses[i]),
              onDelete: () => _deleteStatus(context, ref, statuses[i]),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _showStatusDialog(context, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add status'),
              ),
              PopupMenuButton<String>(
                tooltip: 'Apply a preset',
                onSelected: (String t) => _applyTemplate(context, ref, t),
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'simple',
                        child: Text('Simple · To Do, In Progress, Done'),
                      ),
                      PopupMenuItem<String>(
                        value: 'kanban',
                        child: Text('Kanban · Backlog → Done'),
                      ),
                      PopupMenuItem<String>(
                        value: 'bug',
                        child: Text('Bug tracking'),
                      ),
                      PopupMenuItem<String>(
                        value: 'content',
                        child: Text('Content pipeline'),
                      ),
                    ],
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(
                    Icons.dashboard_customize_outlined,
                    size: 18,
                  ),
                  label: const Text('Apply template'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showStatusDialog(BuildContext context, WorkflowStatus? status) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => _StatusDialog(status: status),
    );
  }

  Future<void> _applyTemplate(
    BuildContext context,
    WidgetRef ref,
    String template,
  ) async {
    try {
      await ref.read(statusesRepositoryProvider).applyTemplate(template);
      ref.invalidate(statusesProvider);
      if (context.mounted) {
        context.showSuccess('Template applied');
      }
    } catch (_) {
      if (context.mounted) {
        context.showError('Could not apply template');
      }
    }
  }

  Future<void> _deleteStatus(
    BuildContext context,
    WidgetRef ref,
    WorkflowStatus s,
  ) async {
    if (s.protected) {
      context.showError('"${s.label}" is built in and can\'t be removed');
      return;
    }
    final bool ok = await confirmDelete(
      context,
      what: '"${s.label}"',
      message: 'You can only delete a status that no task is using.',
    );
    if (!ok) {
      return;
    }
    try {
      await ref.read(statusesRepositoryProvider).delete(s.id);
      ref.invalidate(statusesProvider);
    } catch (_) {
      if (context.mounted) {
        context.showError('Could not delete — move its tasks elsewhere first');
      }
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
  });

  final WorkflowStatus status;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Move up',
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            onPressed: canMoveUp ? onMoveUp : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Move down',
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            onPressed: canMoveDown ? onMoveDown : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: status.protected ? 'Built-in status' : 'Delete',
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: status.protected ? scheme.onSurfaceVariant : scheme.error,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Add / edit a workflow status: a label plus a color from a small palette.
class _StatusDialog extends ConsumerStatefulWidget {
  const _StatusDialog({this.status});
  final WorkflowStatus? status;

  @override
  ConsumerState<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends ConsumerState<_StatusDialog> {
  static const List<String> _palette = <String>[
    '#64748b',
    '#ef4444',
    '#f97316',
    '#f59e0b',
    '#22c55e',
    '#0ea5e9',
    '#6366f1',
    '#8b5cf6',
    '#ec4899',
    '#14b8a6',
  ];

  late final TextEditingController _label = TextEditingController(
    text: widget.status?.label ?? '',
  );
  late String _color = widget.status?.colorHex ?? _palette.first;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.status != null;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(statusesRepositoryProvider);
      if (_isEdit) {
        await repo.update(
          widget.status!.id,
          label: label,
          color: _color,
          position: widget.status!.position,
        );
      } else {
        await repo.create(label: label, color: _color);
      }
      ref.invalidate(statusesProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not save status';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_isEdit ? 'Edit status' : 'New status'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _label,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Text(
              'Color',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final String hex in _palette)
                  _ColorDot(
                    hex: hex,
                    selected: hex == _color,
                    onTap: () => setState(() => _color = hex),
                  ),
              ],
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = WorkflowStatus(id: 0, colorHex: hex).color;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
