import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/project.dart';
import '../../data/models/sprint.dart';
import '../../data/models/task.dart';
import '../../data/models/team_member.dart';
import '../projects/providers/projects_providers.dart';
import '../sprints/providers/sprints_providers.dart';
import '../tasks/providers/tasks_providers.dart';
import '../team/providers/team_providers.dart';

enum _View { workload, roadmap }

/// Capacity planning + a cross-project roadmap, computed from the live task,
/// sprint and project data (AGENTS.md §1 feature page).
class PlanningPage extends ConsumerStatefulWidget {
  const PlanningPage({super.key});

  @override
  ConsumerState<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends ConsumerState<PlanningPage> {
  _View _view = _View.workload;
  double _capacity = 40;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        PageHeader(
          title: 'Planning',
          subtitle: 'Workload, capacity and the roadmap',
          actions: <Widget>[
            SegmentedButton<_View>(
              segments: const <ButtonSegment<_View>>[
                ButtonSegment<_View>(
                  value: _View.workload,
                  icon: Icon(Icons.groups_2_outlined),
                  label: Text('Workload'),
                ),
                ButtonSegment<_View>(
                  value: _View.roadmap,
                  icon: Icon(Icons.timeline_outlined),
                  label: Text('Roadmap'),
                ),
              ],
              selected: <_View>{_view},
              showSelectedIcon: false,
              onSelectionChanged: (Set<_View> s) =>
                  setState(() => _view = s.first),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_view == _View.workload)
          _WorkloadView(
            capacity: _capacity,
            onCapacity: (double v) => setState(() => _capacity = v),
          )
        else
          const _RoadmapView(),
      ],
    );
  }
}

/// Aggregated open-work load for one assignee.
class _Load {
  int tasks = 0;
  int minutes = 0;
  int points = 0;
  int overdue = 0;

  double get hours => minutes / 60.0;
}

class _WorkloadView extends ConsumerWidget {
  const _WorkloadView({required this.capacity, required this.onCapacity});

  final double capacity;
  final ValueChanged<double> onCapacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Task> tasks =
        ref.watch(tasksProvider).asData?.value ?? const <Task>[];
    final List<TeamMember> members =
        ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[];

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final Map<int, _Load> byUser = <int, _Load>{};
    final _Load unassigned = _Load();
    for (final Task t in tasks) {
      if (t.done || t.parentId != null) {
        continue;
      }
      final bool overdue =
          t.dueDate != null && t.dueDate!.toLocal().isBefore(today);
      void add(_Load l) {
        l.tasks++;
        l.minutes += t.estimateMinutes;
        l.points += t.points;
        if (overdue) {
          l.overdue++;
        }
      }

      if (t.assigneeIds.isEmpty) {
        add(unassigned);
      } else {
        for (final int id in t.assigneeIds) {
          add(byUser.putIfAbsent(id, () => _Load()));
        }
      }
    }

    final List<TeamMember> ordered = <TeamMember>[...members]
      ..sort(
        (TeamMember a, TeamMember b) =>
            (byUser[b.id]?.minutes ?? 0).compareTo(byUser[a.id]?.minutes ?? 0),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DashboardCard(
          child: Row(
            children: <Widget>[
              Icon(Icons.speed_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              const Text(
                'Weekly capacity',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Expanded(
                child: Slider(
                  value: capacity,
                  min: 10,
                  max: 80,
                  divisions: 14,
                  label: '${capacity.round()}h',
                  onChanged: onCapacity,
                ),
              ),
              Text(
                '${capacity.round()}h / person',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DashboardCard(
          title: 'Team workload',
          child: members.isEmpty
              ? Text(
                  'No team members yet.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              : Column(
                  children: <Widget>[
                    for (final TeamMember m in ordered)
                      _WorkloadRow(
                        name: m.name.isEmpty ? m.email : m.name,
                        avatarUrl: m.avatarUrl,
                        load: byUser[m.id] ?? _Load(),
                        capacity: capacity,
                      ),
                    if (unassigned.tasks > 0)
                      _WorkloadRow(
                        name: 'Unassigned',
                        avatarUrl: null,
                        load: unassigned,
                        capacity: capacity,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _WorkloadRow extends StatelessWidget {
  const _WorkloadRow({
    required this.name,
    required this.avatarUrl,
    required this.load,
    required this.capacity,
  });

  final String name;
  final String? avatarUrl;
  final _Load load;
  final double capacity;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double util = capacity <= 0 ? 0 : load.hours / capacity;
    final Color color = util > 1.0
        ? AppColors.rose
        : (util >= 0.8 ? AppColors.amber : AppColors.green);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              UserAvatar(name: name, radius: 16, imageUrl: avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _Stat(label: 'tasks', value: '${load.tasks}'),
              _Stat(label: 'pts', value: '${load.points}'),
              _Stat(
                label: 'overdue',
                value: '${load.overdue}',
                color: load.overdue > 0 ? AppColors.rose : null,
              ),
              SizedBox(
                width: 70,
                child: Text(
                  '${load.hours.toStringAsFixed(1)}h',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: util.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                child: Text(
                  '${(util * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color ?? scheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

const double _dayW = 7;
const double _rowH = 40;
const double _headerH = 26;
const double _barH = 24;

class _RoadmapView extends ConsumerWidget {
  const _RoadmapView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Sprint> sprints =
        ref.watch(sprintsProvider).asData?.value ?? const <Sprint>[];
    final List<Project> projects =
        ref.watch(projectsProvider).asData?.value ?? const <Project>[];

    DateTime dayOnly(DateTime d) {
      final DateTime l = d.toLocal();
      return DateTime(l.year, l.month, l.day);
    }

    final List<Sprint> dated = sprints
        .where((Sprint s) => s.startDate != null && s.endDate != null)
        .toList(growable: false);
    final List<Project> due = projects
        .where((Project p) => p.dueDate != null)
        .toList(growable: false);

    if (dated.isEmpty && due.isEmpty) {
      return const EmptyState(
        icon: Icons.timeline_outlined,
        message:
            'Give sprints start/end dates (or projects a due date) to '
            'see the roadmap.',
      );
    }

    final List<DateTime> points = <DateTime>[
      for (final Sprint s in dated) ...<DateTime>[
        dayOnly(s.startDate!),
        dayOnly(s.endDate!),
      ],
      for (final Project p in due) dayOnly(p.dueDate!),
    ];
    DateTime min = points.first;
    DateTime max = points.first;
    for (final DateTime d in points) {
      if (d.isBefore(min)) {
        min = d;
      }
      if (d.isAfter(max)) {
        max = d;
      }
    }
    final DateTime rangeStart = min.subtract(const Duration(days: 3));
    final DateTime rangeEnd = max.add(const Duration(days: 3));
    final int days = rangeEnd.difference(rangeStart).inDays + 1;
    final double total = days * _dayW;
    final double bodyH = _headerH + dated.length * _rowH + 48;
    int offset(DateTime d) => dayOnly(d).difference(rangeStart).inDays;

    return DashboardCard(
      title: 'Roadmap',
      child: SizedBox(
        height: bodyH + 16,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: total < 600 ? 600 : total,
            height: bodyH,
            child: Stack(
              children: <Widget>[
                // Month labels along the top.
                for (final _MonthTick t in _months(rangeStart, rangeEnd))
                  Positioned(
                    left: t.dayOffset * _dayW,
                    top: 0,
                    child: Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                // Sprint bars.
                for (int i = 0; i < dated.length; i++)
                  Positioned(
                    left: offset(dated[i].startDate!) * _dayW,
                    top: _headerH + i * _rowH,
                    width:
                        ((offset(dated[i].endDate!) -
                                    offset(dated[i].startDate!) +
                                    1) *
                                _dayW)
                            .clamp(_dayW * 2, total),
                    height: _barH,
                    child: _SprintBar(sprint: dated[i]),
                  ),
                // Project due-date markers.
                for (final Project p in due)
                  Positioned(
                    left: offset(p.dueDate!) * _dayW - 7,
                    top: _headerH + dated.length * _rowH + 12,
                    child: Tooltip(
                      message:
                          '${p.name} · due ${shortDate(p.dueDate!.toLocal())}',
                      child: Column(
                        children: <Widget>[
                          Transform.rotate(
                            angle: 0.785398,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.rose,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_MonthTick> _months(DateTime start, DateTime end) {
    final List<_MonthTick> out = <_MonthTick>[];
    DateTime m = DateTime(start.year, start.month, 1);
    while (m.isBefore(end)) {
      final int off = m.difference(start).inDays;
      if (off >= 0) {
        out.add(_MonthTick(off, _monthLabel(m)));
      }
      m = DateTime(m.year, m.month + 1, 1);
    }
    return out;
  }

  String _monthLabel(DateTime d) {
    const List<String> names = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${names[d.month - 1]} ${d.year}';
  }
}

class _MonthTick {
  const _MonthTick(this.dayOffset, this.label);
  final int dayOffset;
  final String label;
}

class _SprintBar extends StatelessWidget {
  const _SprintBar({required this.sprint});
  final Sprint sprint;

  @override
  Widget build(BuildContext context) {
    final Color color = sprint.status.color;
    return Tooltip(
      message:
          '${sprint.name} · ${sprint.donePoints}/${sprint.totalPoints} pts',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Text(
          sprint.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
