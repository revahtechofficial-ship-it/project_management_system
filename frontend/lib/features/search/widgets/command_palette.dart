import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/favorite.dart';
import '../../../data/models/project_hit.dart';
import '../../../data/models/search_results.dart';
import '../../../data/models/task.dart';
import '../../favorites/providers/favorites_providers.dart';
import '../../reminders/widgets/reminder_dialog.dart';
import '../../tasks/providers/tasks_providers.dart';
import '../../tasks/widgets/task_form_dialog.dart';
import '../providers/search_providers.dart';
import 'shortcuts_help.dart';

/// Opens the global search command palette (also bound to Ctrl/Cmd+K).
Future<void> showCommandPalette(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (BuildContext _) => const CommandPalette(),
  );
}

/// What a quick action does when chosen.
enum _ActionKind { navigate, newTask, reminder }

/// A command-bar quick action (navigation or a create action).
class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.kind,
    this.route = '',
  });

  final String label;
  final IconData icon;
  final _ActionKind kind;
  final String route;
}

const List<_QuickAction> _quickActions = <_QuickAction>[
  _QuickAction(
    label: 'New task',
    icon: Icons.add_task,
    kind: _ActionKind.newTask,
  ),
  _QuickAction(
    label: 'Set a reminder',
    icon: Icons.notifications_active_outlined,
    kind: _ActionKind.reminder,
  ),
  _QuickAction(label: 'Ask AI Assistant', icon: Icons.auto_awesome, kind: _ActionKind.navigate, route: '/ai'),
  _QuickAction(label: 'Go to Dashboard', icon: Icons.dashboard_outlined, kind: _ActionKind.navigate, route: '/'),
  _QuickAction(label: 'Go to Tasks', icon: Icons.check_circle_outline, kind: _ActionKind.navigate, route: '/tasks'),
  _QuickAction(label: 'Go to Projects', icon: Icons.folder_outlined, kind: _ActionKind.navigate, route: '/projects'),
  _QuickAction(label: 'Go to Sprints', icon: Icons.directions_run, kind: _ActionKind.navigate, route: '/sprints'),
  _QuickAction(label: 'Go to Pages', icon: Icons.description_outlined, kind: _ActionKind.navigate, route: '/pages'),
  _QuickAction(label: 'Go to Chat', icon: Icons.chat_bubble_outline, kind: _ActionKind.navigate, route: '/chat'),
  _QuickAction(label: 'Go to Inbox', icon: Icons.inbox_outlined, kind: _ActionKind.navigate, route: '/notifications'),
  _QuickAction(label: 'Go to Dashboards', icon: Icons.space_dashboard_outlined, kind: _ActionKind.navigate, route: '/dashboards'),
  _QuickAction(label: 'Go to Planning', icon: Icons.insights_outlined, kind: _ActionKind.navigate, route: '/planning'),
  _QuickAction(label: 'Go to Resources', icon: Icons.event_available_outlined, kind: _ActionKind.navigate, route: '/resources'),
  _QuickAction(label: 'Go to Goals', icon: Icons.flag_outlined, kind: _ActionKind.navigate, route: '/goals'),
  _QuickAction(label: 'Go to Time', icon: Icons.timer_outlined, kind: _ActionKind.navigate, route: '/time'),
  _QuickAction(label: 'Go to Reports', icon: Icons.bar_chart_outlined, kind: _ActionKind.navigate, route: '/reports'),
  _QuickAction(label: 'Go to Activity', icon: Icons.history, kind: _ActionKind.navigate, route: '/activity'),
  _QuickAction(label: 'Go to Automation', icon: Icons.bolt_outlined, kind: _ActionKind.navigate, route: '/automation'),
  _QuickAction(label: 'Go to Integrations', icon: Icons.extension_outlined, kind: _ActionKind.navigate, route: '/integrations'),
  _QuickAction(label: 'Go to Settings', icon: Icons.settings_outlined, kind: _ActionKind.navigate, route: '/settings'),
];

/// A spotlight-style search box that queries tasks and projects, paginates
/// task results, and opens the selected item.
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  static const int _pageSize = 20;

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  bool _hasMore = false;
  int _offset = 0;
  List<Task> _tasks = <Task>[];
  List<ProjectHit> _projects = <ProjectHit>[];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _query = text.trim();
      _search(reset: true);
    });
  }

  Future<void> _search({required bool reset}) async {
    if (_query.isEmpty) {
      setState(() {
        _tasks = <Task>[];
        _projects = <ProjectHit>[];
        _hasMore = false;
        _loading = false;
      });
      return;
    }
    final int offset = reset ? 0 : _offset;
    setState(() => _loading = true);
    try {
      final SearchResults res = await ref
          .read(searchRepositoryProvider)
          .search(_query, limit: _pageSize, offset: offset);
      if (!mounted) {
        return;
      }
      setState(() {
        _tasks = reset ? res.tasks : <Task>[..._tasks, ...res.tasks];
        if (reset) {
          _projects = res.projects;
        }
        _offset = offset + res.tasks.length;
        _hasMore = res.tasks.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openTask(Task task) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => TaskFormDialog(task: task),
    );
    if (saved ?? false) {
      ref.invalidate(tasksProvider);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _openProject(ProjectHit project) {
    final GoRouter router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/projects');
  }

  void _goRoute(String route) {
    final GoRouter router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(route);
  }

  void _runAction(_QuickAction action) {
    final GoRouter router = GoRouter.of(context);
    final BuildContext appContext =
        Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    switch (action.kind) {
      case _ActionKind.navigate:
        router.go(action.route);
      case _ActionKind.newTask:
        showDialog<bool>(
          context: appContext,
          builder: (BuildContext _) => const TaskFormDialog(),
        );
      case _ActionKind.reminder:
        showReminderDialog(appContext);
    }
  }

  List<_QuickAction> get _matchingActions {
    if (_query.isEmpty) {
      return _quickActions;
    }
    final String q = _query.toLowerCase();
    return _quickActions
        .where((_QuickAction a) => a.label.toLowerCase().contains(q))
        .toList(growable: false);
  }

  void _onSubmit() {
    if (_tasks.isNotEmpty) {
      _openTask(_tasks.first);
    } else if (_projects.isNotEmpty) {
      _openProject(_projects.first);
    } else if (_matchingActions.isNotEmpty) {
      _runAction(_matchingActions.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      clipBehavior: Clip.antiAlias,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _SearchField(
              controller: _controller,
              loading: _loading,
              onChanged: _onChanged,
              onSubmit: _onSubmit,
            ),
            const Divider(height: 1),
            Flexible(child: _results(scheme)),
            const Divider(height: 1),
            _Footer(
              onShortcuts: () {
                final BuildContext appContext =
                    Navigator.of(context, rootNavigator: true).context;
                Navigator.of(context).pop();
                showShortcutsHelp(appContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(ColorScheme scheme) {
    final List<_QuickAction> actions = _matchingActions;
    if (_query.isEmpty) {
      final List<Favorite> favorites =
          ref.watch(favoritesProvider).asData?.value ?? const <Favorite>[];
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          if (favorites.isNotEmpty) ...<Widget>[
            _SectionLabel('Favorites'),
            for (final Favorite f in favorites)
              ListTile(
                dense: true,
                leading: const Icon(Icons.star, color: AppColors.amber, size: 20),
                title: Text(
                  f.label.isEmpty ? f.kind : f.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _goRoute(f.route.isEmpty ? '/' : f.route),
              ),
          ],
          _SectionLabel('Quick actions'),
          for (final _QuickAction a in _quickActions)
            ListTile(
              dense: true,
              leading: Icon(a.icon, size: 20),
              title: Text(a.label),
              onTap: () => _runAction(a),
            ),
        ],
      );
    }
    if (_tasks.isEmpty && _projects.isEmpty && actions.isEmpty) {
      return _hint(scheme, _loading ? 'Searching…' : 'No matches found');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        if (actions.isNotEmpty) ...<Widget>[
          _SectionLabel('Actions'),
          for (final _QuickAction a in actions)
            ListTile(
              dense: true,
              leading: Icon(a.icon, size: 20),
              title: Text(a.label),
              onTap: () => _runAction(a),
            ),
        ],
        if (_projects.isNotEmpty) ...<Widget>[
          _SectionLabel('Projects'),
          for (final ProjectHit p in _projects)
            _ProjectRow(project: p, onTap: () => _openProject(p)),
        ],
        if (_tasks.isNotEmpty) ...<Widget>[
          _SectionLabel('Tasks'),
          for (final Task t in _tasks)
            _TaskRow(task: t, onTap: () => _openTask(t)),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : () => _search(reset: false),
                  icon: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.expand_more, size: 18),
                  label: const Text('Show more'),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _hint(ColorScheme scheme, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Text(text,
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.loading,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search…',
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onShortcuts});

  final VoidCallback onShortcuts;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: <Widget>[
          Text(
            'Search, navigate, or run an action',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onShortcuts,
            icon: const Icon(Icons.keyboard_outlined, size: 16),
            label: const Text('Shortcuts'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onTap});
  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        task.done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: task.done ? AppColors.green : task.status.color,
        size: 20,
      ),
      title: Text(task.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        <String>[
          task.status.label,
          if (task.projectName != null) task.projectName!,
          if (task.assigneeName != null) task.assigneeName!,
        ].join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.onTap});
  final ProjectHit project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.folder_outlined,
          color: AppColors.brand, size: 20),
      title:
          Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: project.status.isEmpty ? null : Text(project.status),
      onTap: onTap,
    );
  }
}
