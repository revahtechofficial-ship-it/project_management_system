import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/providers/notifications_providers.dart';
import '../../providers/auth_provider.dart';
import '../constants/app_colors.dart';
import 'glass.dart';
import 'user_avatar.dart';

/// A navigation item in the sidebar.
class _NavItem {
  const _NavItem(this.icon, this.label, this.location);
  final IconData icon;
  final String label;
  final String location;
}

const List<_NavItem> _navItems = <_NavItem>[
  _NavItem(Icons.dashboard_outlined, 'Dashboard', '/'),
  _NavItem(Icons.check_circle_outline, 'Tasks', '/tasks'),
  _NavItem(Icons.folder_outlined, 'Projects', '/projects'),
  _NavItem(Icons.groups_outlined, 'Team', '/team'),
  _NavItem(Icons.bar_chart_outlined, 'Reports', '/reports'),
  _NavItem(Icons.settings_outlined, 'Settings', '/settings'),
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

    if (wide) {
      return Scaffold(
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
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context)
            .colorScheme
            .surface
            .withValues(alpha: 0.55),
        title: const Text('Revah Management System'),
        actions: const <Widget>[_NotificationsButton(), _AvatarMenu()],
      ),
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        child: _Sidebar(location: location),
      ),
      body: AppBackground(child: child),
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
            color:
                scheme.surface.withValues(alpha: dark ? 0.45 : 0.6),
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).asData?.value.user;

    return _Chrome(
      border: Border(right: BorderSide(color: scheme.outlineVariant)),
      child: SizedBox(
        width: 256,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.dashboard_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Revah MS',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: <Widget>[
                    for (final _NavItem item in _navItems)
                      _NavTile(
                          item: item, selected: location == item.location),
                  ],
                ),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: 0.6)),
              ListTile(
                leading: UserAvatar(name: user?.name ?? '', radius: 18),
                title: Text(user?.name ?? 'User',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(user?.email ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
              const SizedBox(height: 8),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Row(
                children: <Widget>[
                  Icon(item.icon,
                      size: 20,
                      color: selected
                          ? Colors.white
                          : scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          selected ? Colors.white : scheme.onSurface,
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
              Spacer(),
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
        if (v == 'logout') {
          ref.read(authControllerProvider.notifier).logout();
        } else {
          context.go('/settings');
        }
      },
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'Profile', child: Text('Profile')),
        PopupMenuItem<String>(value: 'Settings', child: Text('Settings')),
        PopupMenuDivider(),
        PopupMenuItem<String>(value: 'logout', child: Text('Sign out')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: UserAvatar(name: user?.name ?? '', radius: 17),
      ),
    );
  }
}
