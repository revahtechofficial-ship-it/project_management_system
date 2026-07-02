import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/one_on_one.dart';
import '../../data/models/team_member.dart';
import '../../data/repositories/one_on_ones_repository.dart';
import '../../providers/auth_provider.dart';
import '../team/providers/team_providers.dart';
import 'providers/one_on_ones_providers.dart';

/// 1:1s & check-ins: recurring meetings between a manager and a report with a
/// shared agenda, notes and checkable action items (AGENTS.md §1 feature page).
class OneOnOnesPage extends ConsumerWidget {
  const OneOnOnesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OneOnOne>> async = ref.watch(oneOnOnesProvider);
    final int myId =
        ref.watch(authControllerProvider).asData?.value.user?.id ?? 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: '1:1s',
            subtitle: 'Recurring check-ins with agendas and action items',
            actions: <Widget>[
              FilledButton.icon(
                onPressed: () => _newMeeting(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New 1:1'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(oneOnOnesProvider),
              ),
              data: (List<OneOnOne> meetings) {
                if (meetings.isEmpty) {
                  return EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No 1:1s yet',
                    message: 'Schedule a recurring check-in with a teammate to '
                        'keep agendas and action items in one place.',
                    actionLabel: 'New 1:1',
                    onAction: () => _newMeeting(context, ref),
                  );
                }
                return ListView(
                  children: <Widget>[
                    for (final OneOnOne m in meetings)
                      _MeetingCard(meeting: m, myId: myId),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _newMeeting(BuildContext context, WidgetRef ref) async {
    final bool? created = await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => const _NewMeetingDialog(),
    );
    if (created ?? false) {
      ref.invalidate(oneOnOnesProvider);
    }
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.myId});
  final OneOnOne meeting;
  final int myId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String other = meeting.otherName(myId);
    final bool upcoming = meeting.scheduledAt.isAfter(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DashboardCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showDialog<void>(
            context: context,
            builder: (BuildContext _) =>
                _MeetingDetailDialog(meetingId: meeting.id),
          ),
          child: Row(
            children: <Widget>[
              UserAvatar(name: other, radius: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      other.isEmpty ? 'Teammate' : other,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatLongDate(meeting.scheduledAt.toLocal())} · '
                      '${_time(meeting.scheduledAt.toLocal())}'
                      '  ·  You are the ${meeting.isManager(myId) ? 'manager' : 'report'}',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (upcoming ? AppColors.green : AppColors.slate)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  upcoming ? relativeTime(meeting.scheduledAt) : 'Past',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: upcoming ? AppColors.green : AppColors.slate,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

String _time(DateTime d) {
  final int h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final String m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Picks a report and a date/time to schedule a new 1:1.
class _NewMeetingDialog extends ConsumerStatefulWidget {
  const _NewMeetingDialog();

  @override
  ConsumerState<_NewMeetingDialog> createState() => _NewMeetingDialogState();
}

class _NewMeetingDialogState extends ConsumerState<_NewMeetingDialog> {
  int? _reportId;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  bool _busy = false;

  Future<void> _pickDate() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() => _date = d);
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? t =
        await showTimePicker(context: context, initialTime: _time);
    if (t != null) {
      setState(() => _time = t);
    }
  }

  Future<void> _save() async {
    if (_reportId == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    final DateTime when = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute);
    try {
      await ref
          .read(oneOnOnesRepositoryProvider)
          .create(reportId: _reportId!, scheduledAt: when);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showError('Could not schedule: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int myId =
        ref.watch(authControllerProvider).asData?.value.user?.id ?? 0;
    final List<TeamMember> members =
        (ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[])
            .where((TeamMember m) => m.id != myId)
            .toList();
    return AlertDialog(
      title: const Text('New 1:1'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<int>(
              initialValue: _reportId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'With'),
              items: <DropdownMenuItem<int>>[
                for (final TeamMember m in members)
                  DropdownMenuItem<int>(
                    value: m.id,
                    child: Text(m.name.isEmpty ? m.email : m.name,
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (int? v) => setState(() => _reportId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(shortDate(_date)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _reportId == null || _busy ? null : _save,
          child: const Text('Schedule'),
        ),
      ],
    );
  }
}

/// The 1:1 detail: agenda, shared notes and action items, each editable.
class _MeetingDetailDialog extends ConsumerWidget {
  const _MeetingDetailDialog({required this.meetingId});
  final int meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OneOnOneDetail> async =
        ref.watch(oneOnOneDetailProvider(meetingId));
    final int myId =
        ref.watch(authControllerProvider).asData?.value.user?.id ?? 0;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: async.when(
          loading: () => const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator())),
          error: (Object e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorNotice(error: e),
          ),
          data: (OneOnOneDetail detail) {
            final OneOnOne m = detail.meeting;
            final List<OneOnOneItem> items = detail.items;
            List<OneOnOneItem> of(String kind) =>
                items.where((OneOnOneItem i) => i.kind == kind).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Header(meeting: m, myId: myId),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    children: <Widget>[
                      _Section(
                        title: 'Agenda',
                        kind: 'agenda',
                        icon: Icons.list_alt_outlined,
                        meetingId: meetingId,
                        items: of('agenda'),
                      ),
                      const SizedBox(height: 18),
                      _Section(
                        title: 'Shared notes',
                        kind: 'note',
                        icon: Icons.sticky_note_2_outlined,
                        meetingId: meetingId,
                        items: of('note'),
                      ),
                      const SizedBox(height: 18),
                      _Section(
                        title: 'Action items',
                        kind: 'action',
                        icon: Icons.checklist_rounded,
                        meetingId: meetingId,
                        items: of('action'),
                        checkable: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.meeting, required this.myId});
  final OneOnOne meeting;
  final int myId;

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    final DateTime current = meeting.scheduledAt.toLocal();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !context.mounted) {
      return;
    }
    final TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (t == null) {
      return;
    }
    final DateTime when =
        DateTime(d.year, d.month, d.day, t.hour, t.minute);
    await ref.read(oneOnOnesRepositoryProvider).reschedule(meeting.id, when);
    ref.invalidate(oneOnOneDetailProvider(meeting.id));
    ref.invalidate(oneOnOnesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok = await confirmDelete(context, what: 'this 1:1');
    if (!ok) {
      return;
    }
    await ref.read(oneOnOnesRepositoryProvider).delete(meeting.id);
    ref.invalidate(oneOnOnesProvider);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool manager = meeting.isManager(myId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: <Widget>[
          UserAvatar(name: meeting.otherName(myId), radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '1:1 with ${meeting.otherName(myId)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${formatLongDate(meeting.scheduledAt.toLocal())} · '
                  '${_time(meeting.scheduledAt.toLocal())}',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Reschedule',
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: () => _reschedule(context, ref),
          ),
          if (manager)
            IconButton(
              tooltip: 'Delete 1:1',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref),
            ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.kind,
    required this.icon,
    required this.meetingId,
    required this.items,
    this.checkable = false,
  });
  final String title;
  final String kind;
  final IconData icon;
  final int meetingId;
  final List<OneOnOneItem> items;
  final bool checkable;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Nothing yet.',
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant)),
          )
        else
          for (final OneOnOneItem i in items)
            _ItemRow(item: i, meetingId: meetingId, checkable: checkable),
        _AddItemRow(meetingId: meetingId, kind: kind),
      ],
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    required this.item,
    required this.meetingId,
    required this.checkable,
  });
  final OneOnOneItem item;
  final int meetingId;
  final bool checkable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (checkable)
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: item.done,
                onChanged: (bool? v) async {
                  await ref
                      .read(oneOnOnesRepositoryProvider)
                      .setItemDone(item.id, v ?? false);
                  ref.invalidate(oneOnOneDetailProvider(meetingId));
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Icon(Icons.circle, size: 6, color: scheme.onSurfaceVariant),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                item.body,
                style: TextStyle(
                  decoration: checkable && item.done
                      ? TextDecoration.lineThrough
                      : null,
                  color: checkable && item.done
                      ? scheme.onSurfaceVariant
                      : null,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
            onPressed: () async {
              await ref.read(oneOnOnesRepositoryProvider).deleteItem(item.id);
              ref.invalidate(oneOnOneDetailProvider(meetingId));
            },
          ),
        ],
      ),
    );
  }
}

class _AddItemRow extends ConsumerStatefulWidget {
  const _AddItemRow({required this.meetingId, required this.kind});
  final int meetingId;
  final String kind;

  @override
  ConsumerState<_AddItemRow> createState() => _AddItemRowState();
}

class _AddItemRowState extends ConsumerState<_AddItemRow> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String body = _controller.text.trim();
    if (body.isEmpty || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(oneOnOnesRepositoryProvider)
          .addItem(widget.meetingId, widget.kind, body);
      _controller.clear();
      ref.invalidate(oneOnOneDetailProvider(widget.meetingId));
    } catch (e) {
      if (mounted) {
        context.showError('Could not add: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                isDense: true,
                hintText: switch (widget.kind) {
                  'note' => 'Add a note',
                  'action' => 'Add an action item',
                  _ => 'Add an agenda item',
                },
              ),
              onSubmitted: (_) => _add(),
            ),
          ),
          IconButton(
            tooltip: 'Add',
            icon: const Icon(Icons.add, size: 20),
            onPressed: _busy ? null : _add,
          ),
        ],
      ),
    );
  }
}
