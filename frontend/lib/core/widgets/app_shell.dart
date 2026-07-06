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
import '../../features/settings/providers/settings_providers.dart';
import '../../data/models/auth_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/sidebar_provider.dart';
import '../../providers/theme_provider.dart';
import '../constants/app_colors.dart';
import '../constants/breakpoints.dart';
import 'glass.dart';
import 'motion.dart';
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
    _NavItem(Icons.wb_sunny_outlined, 'My Day', '/focus'),
    _NavItem(Icons.check_circle_outline, 'Tasks', '/tasks'),
    _NavItem(Icons.directions_run, 'Sprints', '/sprints'),
    _NavItem(Icons.rocket_launch_outlined, 'Releases', '/releases'),
    _NavItem(Icons.bug_report_outlined, 'Incidents', '/incidents'),
    _NavItem(Icons.commit, 'Code', '/git'),
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
    _NavItem(Icons.forum_outlined, '1:1s', '/one-on-ones'),
    _NavItem(Icons.beach_access_outlined, 'Leave', '/leave'),
    _NavItem(Icons.verified_outlined, 'Approvals', '/approvals'),
  ]),
  _NavGroup('Operations', <_NavItem>[
    _NavItem(Icons.inventory_2_outlined, 'Inventory', '/assets'),
    _NavItem(Icons.receipt_long_outlined, 'Expenses', '/expenses'),
    _NavItem(Icons.account_balance_wallet_outlined, 'Budgets', '/budgets'),
    _NavItem(Icons.request_quote_outlined, 'Invoices', '/invoices'),
  ]),
  _NavGroup('Insights', <_NavItem>[
    _NavItem(Icons.map_outlined, 'Roadmap', '/roadmap'),
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
    final bool wide =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.medium;

    // Record the visit for the command palette's "Recent" list (after the
    // frame, so we never mutate a provider mid-build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentPagesProvider.notifier).visit(location);
    });

    // Keep the browser tab/title in sync with the current page so history and
    // multiple tabs are legible.
    final String pageTitle = _pageTitleFor(location);
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: pageTitle.isEmpty
            ? 'Revah Management System'
            : '$pageTitle · Revah',
        primaryColor: AppColors.brand.toARGB32(),
      ),
    );

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

    final Widget page = _RoutedPage(location: location, child: child);

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
                        Expanded(child: page),
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
              child: _Sidebar(location: location, collapsible: false),
            ),
            body: AppBackground(child: page),
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

/// Cross-fades + slides the routed page when the location changes, giving a
/// subtle transition between in-app screens. Instant under reduced motion.
class _RoutedPage extends StatelessWidget {
  const _RoutedPage({required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) {
      return child;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey<String>(location), child: child),
    );
  }
}

/// A flat, solid strip used for the sidebar and top bar chrome, separated from
/// the page by a hairline border.
class _Chrome extends StatelessWidget {
  const _Chrome({required this.child, required this.border});
  final Widget child;
  final BoxBorder border;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface, border: border),
      child: child,
    );
  }
}

class _Sidebar extends ConsumerStatefulWidget {
  const _Sidebar({required this.location, this.collapsible = true});
  final String location;

  /// Whether this sidebar may collapse to an icon rail. False in the mobile
  /// drawer, where collapsing makes no sense.
  final bool collapsible;

  @override
  ConsumerState<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<_Sidebar> {
  /// Titles of collapsed groups. Every group starts collapsed so the menu
  /// opens compact (section headers only); tapping a header expands it. The
  /// set persists while the shell is mounted (i.e. across page navigations).
  final Set<String> _collapsed = <String>{
    for (final _NavGroup group in _navGroups) group.title,
  };

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
    final AuthUser? user = ref.watch(authControllerProvider).asData?.value.user;
    final String location = widget.location;
    final bool isAdmin = user?.isAdmin ?? false;
    // Auto-collapse to the icon rail on tighter widths; above the breakpoint the
    // user's manual toggle decides.
    final bool autoRail = widget.collapsible &&
        MediaQuery.sizeOf(context).width < AppBreakpoints.expanded;
    final bool rail =
        autoRail || (widget.collapsible && ref.watch(sidebarCollapsedProvider));

    final bool reduceMotion =
        ref.watch(settingsControllerProvider).reduceMotion;
    return _Chrome(
      border: Border(right: BorderSide(color: scheme.outlineVariant)),
      child: AnimatedSize(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: rail ? 76 : 256,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _header(context, rail, showToggle: !autoRail),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: rail ? 14 : 12,
                      vertical: rail ? 4 : 0,
                    ),
                    children: _navChildren(
                      location,
                      isAdmin,
                      rail,
                      ref.watch(pinnedNavProvider),
                    ),
                  ),
                ),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                _footer(context, user, rail),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool rail, {required bool showToggle}) {
    if (rail) {
      return SizedBox(
        height: 64,
        child: Center(
          child: showToggle
              ? const _CollapseButton(collapsed: true)
              : const SizedBox.shrink(),
        ),
      );
    }
    // Fixed height aligns the wordmark with the top bar and gives it room to
    // breathe instead of hugging the window edge.
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.go('/'),
                  child: const RevahLogo(height: 28),
                ),
              ),
            ),
            if (widget.collapsible && showToggle)
              const _CollapseButton(collapsed: false),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, AuthUser? user, bool rail) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (rail) {
      return Column(
        children: <Widget>[
          Tooltip(
            message: user?.name ?? 'Profile',
            child: IconButton(
              onPressed: () => context.push('/profile'),
              icon: UserAvatar(
                name: user?.name ?? '',
                radius: 16,
                imageUrl: user?.avatarUrl,
              ),
            ),
          ),
          Tooltip(
            message: 'Sign out',
            child: IconButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
            ),
          ),
        ],
      );
    }
    return Column(
      children: <Widget>[
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
          trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      ],
    );
  }

  /// Builds the nav list. In rail mode, section headers are replaced by thin
  /// dividers and tiles render icon-only with tooltips; otherwise groups carry
  /// collapsible headers. Admin-only items and empty groups are filtered out.
  List<Widget> _navChildren(
    String location,
    bool isAdmin,
    bool rail,
    List<String> pinned,
  ) {
    final List<Widget> children = <Widget>[
      _NavTile(
        item: _dashboardItem,
        selected: location == _dashboardItem.location,
        collapsed: rail,
      ),
      if (!rail) const SizedBox(height: 4),
    ];
    // Pinned favorites, at the very top.
    final List<_NavItem> pinnedItems = <_NavItem>[
      for (final String loc in pinned)
        if (_navItemFor(loc) case final _NavItem item)
          if (!item.adminOnly || isAdmin) item,
    ];
    if (pinnedItems.isNotEmpty) {
      if (rail) {
        children.add(const _RailDivider());
      } else {
        children.add(const _MiniLabel('Pinned'));
      }
      for (final _NavItem item in pinnedItems) {
        children.add(
          _NavTile(
            item: item,
            selected: location == item.location,
            collapsed: rail,
          ),
        );
      }
    }
    for (final _NavGroup group in _navGroups) {
      final List<_NavItem> items = <_NavItem>[
        for (final _NavItem item in group.items)
          if (!item.adminOnly || isAdmin) item,
      ];
      if (items.isEmpty) {
        continue;
      }
      if (rail) {
        children.add(const _RailDivider());
        for (final _NavItem item in items) {
          children.add(
            _NavTile(
              item: item,
              selected: location == item.location,
              collapsed: true,
            ),
          );
        }
      } else {
        children.add(
          _NavSection(
            title: group.title,
            collapsed: _collapsed.contains(group.title),
            hasActive: items.any((_NavItem i) => i.location == location),
            onToggle: () => _toggle(group.title),
            tiles: <Widget>[
              for (final _NavItem item in items)
                _NavTile(item: item, selected: location == item.location),
            ],
          ),
        );
      }
    }
    return children;
  }
}

/// A sidebar group: a tappable header over its tiles, with the tiles smoothly
/// collapsing to (and expanding from) zero height.
class _NavSection extends StatelessWidget {
  const _NavSection({
    required this.title,
    required this.collapsed,
    required this.hasActive,
    required this.onToggle,
    required this.tiles,
  });
  final String title;
  final bool collapsed;

  /// Whether the current route lives inside this group (drives the dot that
  /// marks a collapsed group holding the active page).
  final bool hasActive;
  final VoidCallback onToggle;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(
          title: title,
          collapsed: collapsed,
          showActiveDot: collapsed && hasActive,
          onTap: onToggle,
        ),
        AnimatedSize(
          duration: prefersReducedMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: collapsed
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: tiles,
                ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

/// A one-tap button that collapses the sidebar to an icon rail (and back).
class _CollapseButton extends ConsumerWidget {
  const _CollapseButton({required this.collapsed});
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      icon: Icon(collapsed ? Icons.menu : Icons.menu_open),
      onPressed: () => ref.read(sidebarCollapsedProvider.notifier).toggle(),
    );
  }
}

/// A hairline separator between icon groups in the collapsed rail.
class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Divider(
        height: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
  }
}

/// A tappable, collapsible group label between sidebar sections.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.collapsed,
    required this.onTap,
    this.showActiveDot = false,
  });
  final String title;
  final bool collapsed;
  final VoidCallback onTap;

  /// Shows an accent dot next to the title (used when a collapsed group holds
  /// the active route).
  final bool showActiveDot;

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
              if (showActiveDot) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
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

/// A small static section label (non-collapsible), e.g. "Pinned".
class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 6, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NavTile extends ConsumerWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    this.collapsed = false,
  });
  final _NavItem item;
  final bool selected;
  final bool collapsed;

  Future<void> _showPinMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final bool pinned = ref.read(pinnedNavProvider).contains(item.location);
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final String? choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'pin',
          child: Row(
            children: <Widget>[
              Icon(
                pinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(pinned ? 'Unpin from sidebar' : 'Pin to sidebar'),
            ],
          ),
        ),
      ],
    );
    if (choice == 'pin') {
      await ref.read(pinnedNavProvider.notifier).toggle(item.location);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color iconColor = selected ? Colors.white : scheme.onSurfaceVariant;
    final Widget inner = collapsed
        ? Center(child: Icon(item.icon, size: 22, color: iconColor))
        : Row(
            children: <Widget>[
              Icon(item.icon, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : scheme.onSurface,
                  ),
                ),
              ),
            ],
          );
    final Widget tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: selected ? AppColors.accentGradient(scheme.primary) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            // Selected tiles already have a gradient fill; give inactive ones a
            // subtle hover so the list feels responsive.
            hoverColor: selected
                ? Colors.transparent
                : scheme.onSurface.withValues(alpha: 0.06),
            onTap: () => context.go(item.location),
            child: Padding(
              padding: collapsed
                  ? const EdgeInsets.symmetric(vertical: 12)
                  : const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: inner,
            ),
          ),
        ),
      ),
    );
    // Right-click (or long-press) a nav item to pin/unpin it.
    final Widget interactive = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (TapDownDetails d) =>
          _showPinMenu(context, ref, d.globalPosition),
      onLongPressStart: (LongPressStartDetails d) =>
          _showPinMenu(context, ref, d.globalPosition),
      child: tile,
    );
    return collapsed
        ? Tooltip(message: item.label, child: interactive)
        : interactive;
  }
}

/// Resolves a human page title for the current route from the nav catalog,
/// with a few fallbacks for routes that have no sidebar entry. Returns '' for
/// the dashboard (its greeting already names the page).
String _pageTitleFor(String location) {
  if (location == '/') {
    return '';
  }
  for (final _NavItem item in <_NavItem>[
    _dashboardItem,
    for (final _NavGroup g in _navGroups) ...g.items,
  ]) {
    if (item.location == location) {
      return item.label;
    }
  }
  switch (location) {
    case '/profile':
      return 'Profile';
    case '/vikunja':
      return 'Vikunja';
    default:
      return '';
  }
}

/// The nav item for [location], if any (dashboard or a group item).
_NavItem? _navItemFor(String location) {
  for (final _NavItem item in <_NavItem>[
    _dashboardItem,
    for (final _NavGroup g in _navGroups) ...g.items,
  ]) {
    if (item.location == location) {
      return item;
    }
  }
  return null;
}

/// The title of the sidebar group that contains [location], if any.
String? _groupTitleFor(String location) {
  for (final _NavGroup g in _navGroups) {
    if (g.items.any((_NavItem i) => i.location == location)) {
      return g.title;
    }
  }
  return null;
}

/// A single crumb: a [label] and an optional [route] to navigate to.
typedef _Crumb = ({String label, String? route});

/// A route-based breadcrumb trail (Home › Section › Page) at the left of the
/// top bar, so users always know where they are and can jump up a level.
class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs();

  List<_Crumb> _crumbsFor(String location) {
    final List<_Crumb> crumbs = <_Crumb>[(label: 'Home', route: '/')];
    if (location == '/') {
      return crumbs;
    }
    final String? group = _groupTitleFor(location);
    if (group != null) {
      crumbs.add((label: group, route: null));
    }
    final String title = _pageTitleFor(location);
    if (title.isNotEmpty) {
      crumbs.add((label: title, route: null));
    }
    return crumbs;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String location = GoRouterState.of(context).matchedLocation;
    final List<_Crumb> crumbs = _crumbsFor(location);
    final List<Widget> row = <Widget>[];
    for (int i = 0; i < crumbs.length; i++) {
      final _Crumb crumb = crumbs[i];
      final bool last = i == crumbs.length - 1;
      if (i > 0) {
        row.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.chevron_right,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ));
      }
      final TextStyle style = TextStyle(
        fontSize: last ? 16 : 13.5,
        fontWeight: last ? FontWeight.w700 : FontWeight.w500,
        color: last ? scheme.onSurface : scheme.onSurfaceVariant,
      );
      if (crumb.route != null && !last) {
        row.add(InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go(crumb.route!),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(crumb.label, style: style),
          ),
        ));
      } else {
        row.add(Text(crumb.label, style: style));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(mainAxisSize: MainAxisSize.min, children: row),
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
              Flexible(child: _Breadcrumbs()),
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
