import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/avatar_crop_dialog.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/enums/custom_field_type.dart';
import '../../data/models/auth_user.dart';
import '../../data/models/custom_field.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../tasks/providers/custom_fields_providers.dart';
import 'providers/settings_providers.dart';
import 'widgets/change_password_dialog.dart';
import 'widgets/custom_field_dialog.dart';

/// Account and preference management. The theme selector and notification
/// switches are fully wired and persisted.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthUser? user =
        ref.watch(authControllerProvider).asData?.value.user;
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
            _AppearanceCard(
              themeMode: themeMode,
              compactMode: settings.compactMode,
            ),
            const SizedBox(height: 16),
            _NotificationsCard(settings: settings),
            if (user?.isAdmin ?? false) ...<Widget>[
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
                UserAvatar(
                    name: name, radius: 28, imageUrl: user?.avatarUrl),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.brand,
                    child: const Icon(Icons.camera_alt,
                        size: 11, color: Colors.white),
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
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(user?.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
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
        type: FileType.image, withData: true);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard({
    required this.themeMode,
    required this.compactMode,
  });

  final ThemeMode themeMode;
  final bool compactMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      title: 'Appearance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Theme',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto)),
                ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode)),
                ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode)),
              ],
              selected: <ThemeMode>{themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (Set<ThemeMode> selection) => ref
                  .read(themeModeProvider.notifier)
                  .setMode(selection.first),
            ),
          ),
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Compact mode'),
            subtitle: const Text('Denser spacing across the app'),
            value: compactMode,
            onChanged: (bool v) => ref
                .read(settingsControllerProvider.notifier)
                .setCompactMode(v),
          ),
        ],
      ),
    );
  }
}

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard({required this.settings});
  final SettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsController c =
        ref.read(settingsControllerProvider.notifier);
    return DashboardCard(
      title: 'Notifications',
      child: Column(
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Email notifications'),
            subtitle: const Text('Task updates and mentions by email'),
            value: settings.emailNotifications,
            onChanged: c.setEmailNotifications,
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
          Text('Add fields that appear on every task.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (fields.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No custom fields yet.',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          for (final CustomField f in fields)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(f.type.icon, color: scheme.onSurfaceVariant),
              title: Text(f.name),
              subtitle: Text(f.type == CustomFieldType.select
                  ? 'Dropdown · ${f.options.join(', ')}'
                  : f.type.label),
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
      BuildContext context, WidgetRef ref, CustomField f) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Delete "${f.name}"?'),
            content: const Text(
                'This removes the field and its values from every task.'),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    await ref.read(customFieldsRepositoryProvider).delete(f.id);
    ref.invalidate(customFieldsProvider);
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Security',
      child: _SettingTile(
        icon: Icons.lock_outline,
        title: 'Change password',
        subtitle: 'Update your account password',
        onTap: () => _changePassword(context),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const ChangePasswordDialog(),
    );
    if ((ok ?? false) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
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
