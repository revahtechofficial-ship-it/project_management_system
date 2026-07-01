import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/favorite.dart';
import '../../data/models/task.dart';
import '../favorites/providers/favorites_providers.dart';
import '../tasks/providers/tasks_providers.dart';
import '../tasks/widgets/task_form_dialog.dart';

/// "My Day": today's due + overdue + starred tasks in one focused lane, next
/// to a Pomodoro timer (AGENTS.md §1 feature page). Everything is derived —
/// no extra persistence — so it always reflects the live task list.
class FocusPage extends ConsumerWidget {
  const FocusPage({super.key});

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    final List<Favorite> favorites =
        ref.watch(favoritesProvider).asData?.value ?? const <Favorite>[];
    final Set<int> starredIds = <int>{
      for (final Favorite f in favorites)
        if (f.kind == 'task') f.itemId,
    };
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final List<Task> open =
        tasks.where((Task t) => !t.done && t.parentId == null).toList();
    final List<Task> overdue = open
        .where((Task t) =>
            t.dueDate != null && t.dueDate!.toLocal().isBefore(today))
        .toList();
    final List<Task> dueToday = open
        .where((Task t) =>
            t.dueDate != null && _sameDay(t.dueDate!.toLocal(), today))
        .toList();
    final Set<int> planned = <int>{
      for (final Task t in overdue) t.id,
      for (final Task t in dueToday) t.id,
    };
    final List<Task> starred = open
        .where((Task t) => starredIds.contains(t.id) && !planned.contains(t.id))
        .toList();

    final bool empty =
        overdue.isEmpty && dueToday.isEmpty && starred.isEmpty;

    final Widget lanes = ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        if (empty)
          const EmptyState(
            icon: Icons.wb_sunny_outlined,
            title: "You're all set",
            message: 'Nothing due today and nothing starred. Enjoy the calm — '
                'or star a task to line it up here.',
          )
        else ...<Widget>[
          if (overdue.isNotEmpty)
            _Lane(
              title: 'Overdue',
              color: AppColors.rose,
              tasks: overdue,
            ),
          if (dueToday.isNotEmpty)
            _Lane(
              title: 'Due today',
              color: AppColors.brand,
              tasks: dueToday,
            ),
          if (starred.isNotEmpty)
            _Lane(
              title: 'Starred',
              color: AppColors.amber,
              tasks: starred,
            ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'My Day',
            subtitle: formatLongDate(now),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                if (c.maxWidth < 900) {
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: <Widget>[
                      const _PomodoroCard(),
                      const SizedBox(height: 16),
                      // A bounded height so the inner ListView lays out.
                      SizedBox(height: 520, child: lanes),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: lanes),
                    const SizedBox(width: 16),
                    const SizedBox(width: 320, child: _PomodoroCard()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({required this.title, required this.color, required this.tasks});
  final String title;
  final Color color;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text('${tasks.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
            const SizedBox(height: 4),
            for (final Task t in tasks) _FocusTaskRow(task: t),
          ],
        ),
      ),
    );
  }
}

class _FocusTaskRow extends ConsumerWidget {
  const _FocusTaskRow({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Checkbox(
        value: task.done,
        onChanged: (bool? v) {
          if (v ?? false) {
            celebrate(context);
          }
          ref.read(tasksProvider.notifier).toggleDone(task.id, v ?? false);
        },
      ),
      title: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: task.projectName == null
          ? null
          : Text(task.projectName!,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      trailing: task.dueDate == null
          ? null
          : Text(
              shortDate(task.dueDate!.toLocal()),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
      onTap: () async {
        final bool? saved = await showDialog<bool>(
          context: context,
          builder: (BuildContext _) => TaskFormDialog(task: task),
        );
        if (saved ?? false) {
          ref.invalidate(tasksProvider);
        }
      },
    );
  }
}

/// A self-contained Pomodoro timer (focus/break) with session counting.
class _PomodoroCard extends StatefulWidget {
  const _PomodoroCard();

  @override
  State<_PomodoroCard> createState() => _PomodoroCardState();
}

class _PomodoroCardState extends State<_PomodoroCard> {
  static const int _focusSeconds = 25 * 60;
  static const int _breakSeconds = 5 * 60;

  Timer? _ticker;
  bool _running = false;
  bool _isBreak = false;
  int _left = _focusSeconds;
  int _completed = 0;

  int get _total => _isBreak ? _breakSeconds : _focusSeconds;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 1) {
        _onElapsed();
      } else {
        setState(() => _left--);
      }
    });
  }

  void _onElapsed() {
    _ticker?.cancel();
    final bool wasFocus = !_isBreak;
    setState(() {
      _running = false;
      _isBreak = !_isBreak;
      _left = _total;
      if (wasFocus) {
        _completed++;
      }
    });
    if (mounted) {
      context.showSuccess(
        wasFocus ? 'Focus session done — take a break 🎉' : 'Break over — back to it',
      );
    }
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _left = _total;
    });
  }

  void _setMode(bool isBreak) {
    _ticker?.cancel();
    setState(() {
      _isBreak = isBreak;
      _running = false;
      _left = _total;
    });
  }

  String get _clock {
    final int m = _left ~/ 60;
    final int s = _left % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = _isBreak ? AppColors.green : scheme.primary;
    final double fraction = _total == 0 ? 0 : (_total - _left) / _total;
    return DashboardCard(
      title: 'Focus timer',
      child: Column(
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('Focus')),
                ButtonSegment<bool>(value: true, label: Text('Break')),
              ],
              selected: <bool>{_isBreak},
              showSelectedIcon: false,
              onSelectionChanged: (Set<bool> s) => _setMode(s.first),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 8,
                    color: color,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _clock,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      _isBreak ? 'Break' : 'Focus',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? 'Pause' : 'Start'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _reset,
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$_completed focus ${_completed == 1 ? 'session' : 'sessions'} today',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
