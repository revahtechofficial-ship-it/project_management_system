import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/call/call_actions.dart';
import '../../features/chat/providers/chat_providers.dart';
import '../../features/chat/widgets/status_picker.dart';
import '../../features/notifications/providers/notifications_providers.dart';
import '../../features/search/widgets/command_palette.dart';
import '../../features/search/widgets/shortcuts_help.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../constants/app_colors.dart';
import 'glass.dart';
import 'revah_logo.dart';
import 'user_avatar.dart';

/// A navigation item in the sidebar.
class _NavItem {
  const _NavItem(this.icon, this.label, this.location, {this.adminOnly = false});
  final IconData icon;
  final String label;
  final String location;
  final bool adminOnly;
}

/// A labelled, collapsible group of [_NavItem]s in the sidebar.
class _NavGroup {
  const _NavGroup(this.title, this.items);
  final String title;
  final List<_NavItem> items;
}

/// Home item, pinned above the grouped sections.
const _NavItem _dashboardItem = _NavItem(
  Icons.dashboard_outlined,
  'Dashboard',
  '/',
);

/// The sidebar grouped by purpose so 20+ destinations stay scannable.
const List<_NavGroup> _navGroups = <_NavGroup>[
  _NavGroup('Work', <_NavItem>[
    _NavItem(Icons.check_circle_outline, 'Tasks', '/tasks'),
    _NavItem(Icons.directions_run, 'Sprints', '/sprints'),
    _NavItem(Icons.rocket_launch_outlined, 'Releases', '/releases'),
    _NavItem(Icons.folder_outlined, 'Projects', '/projects'),
  ]),
  _NavGroup('Plan', <_NavItem>[
    _NavItem(Icons.insights_outlined, 'Planning', '/planning'),
    _NavItem(Icons.flag_outlined, 'Goals', '/goals'),
    _NavItem(Icons.event_available_outlined, 'Resources', '/resources'),
    _NavItem(Icons.timer_outlined, 'Time', '/time'),
  ]),
  _NavGroup('Collaborate', <_NavItem>[
    _NavItem(Icons.chat_bubble_outline, 'Chat', '/chat'),
    _NavItem(Icons.inbox_outlined, 'Inbox', '/notifications'),
    _NavItem(Icons.description_outlined, 'Pages', '/pages'),
    _NavItem(Icons.groups_outlined, 'Team', '/team'),
  ]),
  _NavGroup('Insights', <_NavItem>[
    _NavItem(Icons.space_dashboard_outlined, 'Dashboards', '/dashboards'),
    _NavItem(Icons.bar_chart_outlined, 'Reports', '/reports'),
    _NavItem(Icons.history, 'Activity', '/activity'),
  ]),
  _NavGroup('Automate', <_NavItem>[
    _NavItem(Icons.auto_awesome, 'AI Assistant', '/ai'),
    _NavItem(Icons.bolt_outlined, 'Automation', '/automation'),
    _NavItem(Icons.extension_outlined, 'Integrations', '/integrations'),
  ]),
  _NavGroup('Admin', <_NavItem>[
    _NavItem(
      Icons.admin_panel_settings_outlined,
      'Admin',
      '/admin',
      adminOnly: true,
    ),
    _NavItem(Icons.settings_outlined, 'Settings', '/settings'),
  ]),
];

/// Responsive glassmorphism shell: an aurora backdrop with a frosted sidebar +
/// top bar on wide screens, a drawer on narrow ones (AGENTS.md §1
/// `core/widgets`).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String location = GoRouterState.of(context).matchedLocation;
    final bool wide = MediaQuery.sizeOf(context).width >= 900;

    // Ring an incoming-call prompt anywhere in the app when another member
    // starts a call.
    ref.listen<AsyncValue<Map<String, dynamic>>>(chatEventsProvider, (
      AsyncValue<Map<String, dynamic>>? prev,
      AsyncValue<Map<String, dynamic>> next,
    ) {
      next.whenData((Map<String, dynamic> e) {
        if (e['type'] != 'call') {
          return;
        }
        final int? myId = ref
            .read(authControllerProvider)
            .asData
            ?.value
            .user
            ?.id;
        if (e['from_id'] != myId) {
          showIncomingCall(context, ref, e);
        }
      });
    });

    final Widget scaffold = wide
        ? Scaffold(
            backgroundColor: Colors.transparent,
            body: AppBackground(
              child: Row(
                children: <Widget>[
                  _Sidebar(location: location),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        const _TopBar(),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        : Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.55),
              title: const Text('Revah Management System'),
              actions: const <Widget>[
                _SearchButton(iconOnly: true),
                _ThemeToggleButton(),
                _NotificationsButton(),
                _AvatarMenu(),
              ],
            ),
            drawer: Drawer(
              backgroundColor: Colors.transparent,
              child: _Sidebar(location: location),
            ),
            body: AppBackground(child: child),
          );

    // Ctrl/Cmd+K opens the command bar; "?" shows the shortcuts cheat sheet.
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            showCommandPalette(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            showCommandPalette(context, ref),
        const SingleActivator(LogicalKeyboardKey.slash, shift: true): () =>
            showShortcutsHelp(context),
      },
      child: Focus(autofocus: true, child: scaffold),
    );
  }
}

/// A blurred glass strip used for the sidebar and top bar chrome.
class _Chrome extends StatelessWidget {
  const _Chrome({required this.child, required this.border});
  final Widget child;
  final BoxBorder border;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: dark ? 0.45 : 0.6),
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerStatefulWidget {
  const _Sidebar({required this.location});
  final String location;

  @override
  ConsumerState<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<_Sidebar> {
  /// Titles of groups the user has collapsed. Persists while the shell is
  /// mounted (i.e. across page navigations).
  final Set<String> _collapsed = <String>{};

  void _toggle(String title) {
    setState(() {
      if (!_collapsed.remove(title)) {
        _collapsed.add(title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).asData?.value.user;
    final String location = widget.location;
    final bool isAdmin = user?.isAdmin ?? false;

    return _Chrome(
      border: Border(right: BorderSide(color: scheme.outlineVariant)),
      child: SizedBox(
        width: 256,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.go('/'),
                    child: const RevahLogo(height: 30),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: <Widget>[
                    _NavTile(
                      item: _dashboardItem,
                      selected: location == _dashboardItem.location,
                    ),
                    const SizedBox(height: 4),
                    for (final _NavGroup group in _navGroups)
                      ..._buildGroup(group, location, isAdmin),
                  ],
                ),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.6)),
              ListTile(
                onTap: () => context.push('/profile'),
                leading: UserAvatar(
                  name: user?.name ?? '',
                  radius: 18,
                  imageUrl: user?.avatarUrl,
                ),
                title: Text(
                  user?.name ?? 'User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  user?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a section header plus its tiles (hidden when collapsed). Admin-only
  /// items are filtered, and an empty group is dropped entirely.
  List<Widget> _buildGroup(_NavGroup group, String location, bool isAdmin) {
    final List<_NavItem> items = <_NavItem>[
      for (final _NavItem item in group.items)
        if (!item.adminOnly || isAdmin) item,
    ];
    if (items.isEmpty) {
      return const <Widget>[];
    }
    final bool collapsed = _collapsed.contains(group.title);
    return <Widget>[
      _SectionHeader(
        title: group.title,
        collapsed: collapsed,
        onTap: () => _toggle(group.title),
      ),
      if (!collapsed)
        for (final _NavItem item in items)
          _NavTile(item: item, selected: location == item.location),
      const SizedBox(height: 6),
    ];
  }
}

/// A tappable, collapsible group label between sidebar sections.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.collapsed,
    required this.onTap,
  });
  final String title;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 6, 4),
          child: Row(
            children: <Widget>[
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: collapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected});
  final _NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go(item.location),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Row(
                children: <Widget>[
                  Icon(
                    item.icon,
                    size: 20,
                    color: selected ? Colors.white : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : scheme.onSurface,
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

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return _Chrome(
      border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: const <Widget>[
              _SearchButton(),
              Spacer(),
              _ThemeToggleButton(),
              SizedBox(width: 4),
              _NotificationsButton(),
              SizedBox(width: 8),
              _AvatarMenu(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the global search command palette. Renders as a search "pill" on wide
/// layouts, or a plain icon button ([iconOnly]) in the mobile app bar.
class _SearchButton extends ConsumerWidget {
  const _SearchButton({this.iconOnly = false});
  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (iconOnly) {
      return IconButton(
        tooltip: 'Search',
        icon: const Icon(Icons.search),
        onPressed: () => showCommandPalette(context, ref),
      );
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showCommandPalette(context, ref),
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.search, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Search…', style: TextStyle(color: scheme.onSurfaceVariant)),
              const Spacer(),
              _KbdHint(scheme: scheme),
            ],
          ),
        ),
      ),
    );
  }
}

class _KbdHint extends StatelessWidget {
  const _KbdHint({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'Ctrl K',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A one-tap light/dark switch, always visible in the top bar. Resolves the
/// effective brightness (following the OS when on System) and flips to the
/// opposite explicit mode — the full System/Light/Dark control lives in
/// Settings.
class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final bool isDark = mode == ThemeMode.system
        ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
        : mode == ThemeMode.dark;
    return IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      ),
      onPressed: () => ref
          .read(themeModeProvider.notifier)
          .setMode(isDark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

class _NotificationsButton extends ConsumerWidget {
  const _NotificationsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unread = ref.watch(unreadCountProvider).asData?.value ?? 0;
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.go('/notifications'),
      icon: unread == 0
          ? const Icon(Icons.notifications_outlined)
          : Badge(
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
    );
  }
}

class _AvatarMenu extends ConsumerWidget {
  const _AvatarMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).asData?.value.user;
    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (String v) {
        switch (v) {
          case 'logout':
            ref.read(authControllerProvider.notifier).logout();
          case 'status':
            showStatusPicker(context, ref);
          case 'Profile':
            context.push('/profile');
          default:
            context.go('/settings');
        }
      },
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'status',
          child: ListTile(leading: Icon(Icons.mood), title: Text('Set status')),
        ),
        PopupMenuItem<String>(value: 'Profile', child: Text('Profile')),
        PopupMenuItem<String>(value: 'Settings', child: Text('Settings')),
        PopupMenuDivider(),
        PopupMenuItem<String>(value: 'logout', child: Text('Sign out')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: UserAvatar(
          name: user?.name ?? '',
          radius: 17,
          imageUrl: user?.avatarUrl,
        ),
      ),
    );
  }
}
