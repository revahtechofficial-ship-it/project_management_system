import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/enums/leave_type.dart';
import '../../data/models/leave_request.dart';
import '../../data/repositories/leave_repository.dart';
import '../../providers/auth_provider.dart';
import 'providers/leave_providers.dart';

enum _LeaveView { mine, calendar, approvals }

/// Leave & PTO: request time off, see your balance, browse who's out, and
/// approve requests (admin) — all in one place (AGENTS.md §1 feature page).
class LeavePage extends ConsumerStatefulWidget {
  const LeavePage({super.key});

  @override
  ConsumerState<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends ConsumerState<LeavePage> {
  _LeaveView _view = _LeaveView.mine;

  Future<void> _request() async {
    final bool? made = await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => const _RequestLeaveDialog(),
    );
    if (made ?? false) {
      ref.invalidate(myLeaveProvider);
      ref.invalidate(leaveBalanceProvider);
    }
  }

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
            title: 'Leave',
            subtitle: 'Request time off and see who is out',
            actions: <Widget>[
              SegmentedButton<_LeaveView>(
                segments: <ButtonSegment<_LeaveView>>[
                  const ButtonSegment<_LeaveView>(
                    value: _LeaveView.mine,
                    icon: Icon(Icons.event_available_outlined, size: 18),
                    label: Text('My leave'),
                  ),
                  const ButtonSegment<_LeaveView>(
                    value: _LeaveView.calendar,
                    icon: Icon(Icons.beach_access_outlined, size: 18),
                    label: Text("Who's out"),
                  ),
                  if (isAdmin)
                    const ButtonSegment<_LeaveView>(
                      value: _LeaveView.approvals,
                      icon: Icon(Icons.fact_check_outlined, size: 18),
                      label: Text('Approvals'),
                    ),
                ],
                selected: <_LeaveView>{_view},
                showSelectedIcon: false,
                onSelectionChanged: (Set<_LeaveView> s) =>
                    setState(() => _view = s.first),
              ),
              FilledButton.icon(
                onPressed: _request,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Request leave'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (_view) {
              _LeaveView.mine => const _MyLeaveView(),
              _LeaveView.calendar => const _WhosOutView(),
              _LeaveView.approvals => const _LeaveApprovalsView(),
            },
          ),
        ],
      ),
    );
  }
}

String _range(LeaveRequest l) {
  final DateTime s = l.startDate.toLocal();
  final DateTime e = l.endDate.toLocal();
  if (s.year == e.year && s.month == e.month && s.day == e.day) {
    return shortDate(s);
  }
  return '${shortDate(s)} – ${shortDate(e)}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      'approved' => (AppColors.green, 'Approved'),
      'rejected' => (AppColors.rose, 'Rejected'),
      _ => (AppColors.amber, 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final LeaveType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(type.icon, size: 12, color: type.color),
          const SizedBox(width: 4),
          Text(type.label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: type.color)),
        ],
      ),
    );
  }
}

class _MyLeaveView extends ConsumerWidget {
  const _MyLeaveView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LeaveRequest>> async = ref.watch(myLeaveProvider);
    return ListView(
      children: <Widget>[
        const _BalanceCard(),
        const SizedBox(height: 16),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 24),
            child: LoadingView(),
          ),
          error: (Object e, _) => ErrorNotice(
            error: e,
            onRetry: () => ref.invalidate(myLeaveProvider),
          ),
          data: (List<LeaveRequest> items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.event_available_outlined,
                title: 'No requests yet',
                message: 'Request time off and it will show up here.',
              );
            }
            return Column(
              children: <Widget>[
                for (final LeaveRequest l in items)
                  _MyLeaveRow(leave: l),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final LeaveBalance? b = ref.watch(leaveBalanceProvider).asData?.value;
    final int used = b?.used ?? 0;
    final int allowance = b?.allowance ?? 20;
    final int remaining = b?.remaining ?? allowance;
    final double frac = allowance == 0 ? 0 : (used / allowance).clamp(0.0, 1.0);
    return DashboardCard(
      child: Row(
        children: <Widget>[
          Icon(Icons.beach_access_outlined, color: scheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('$remaining vacation days left',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 6,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Text('$used of $allowance days used this year',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyLeaveRow extends ConsumerWidget {
  const _MyLeaveRow({required this.leave});
  final LeaveRequest leave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DashboardCard(
        child: Row(
          children: <Widget>[
            _TypeChip(type: leave.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('${_range(leave)}  ·  ${leave.days} '
                      '${leave.days == 1 ? 'day' : 'days'}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (leave.note.isNotEmpty)
                    Text(leave.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusChip(status: leave.status),
            if (leave.isPending)
              IconButton(
                tooltip: 'Cancel request',
                icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                onPressed: () async {
                  await ref.read(leaveRepositoryProvider).cancel(leave.id);
                  ref.invalidate(myLeaveProvider);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _WhosOutView extends ConsumerWidget {
  const _WhosOutView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LeaveRequest>> async =
        ref.watch(leaveCalendarProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (Object e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(leaveCalendarProvider),
      ),
      data: (List<LeaveRequest> items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.beach_access_outlined,
            title: 'Everyone is in',
            message: 'No approved time off in the coming weeks.',
          );
        }
        return ListView(
          children: <Widget>[
            for (final LeaveRequest l in items) _WhosOutRow(leave: l),
          ],
        );
      },
    );
  }
}

class _WhosOutRow extends StatelessWidget {
  const _WhosOutRow({required this.leave});
  final LeaveRequest leave;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DashboardCard(
        child: Row(
          children: <Widget>[
            UserAvatar(name: leave.userName, radius: 20,
                imageUrl: leave.avatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(leave.userName.isEmpty ? 'Member' : leave.userName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${_range(leave)}  ·  ${leave.days} '
                      '${leave.days == 1 ? 'day' : 'days'}',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            _TypeChip(type: leave.type),
          ],
        ),
      ),
    );
  }
}

class _LeaveApprovalsView extends ConsumerWidget {
  const _LeaveApprovalsView();

  Future<void> _decide(
      BuildContext context, WidgetRef ref, int id, bool approved) async {
    try {
      await ref.read(leaveRepositoryProvider).decide(id, approved: approved);
      ref.invalidate(pendingLeaveProvider);
      ref.invalidate(leaveCalendarProvider);
      if (context.mounted) {
        context.showSuccess(approved ? 'Leave approved' : 'Leave rejected');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not update: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<LeaveRequest>> async =
        ref.watch(pendingLeaveProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (Object e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(pendingLeaveProvider),
      ),
      data: (List<LeaveRequest> items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'All caught up',
            message: 'No leave requests are waiting for your approval.',
          );
        }
        return ListView(
          children: <Widget>[
            for (final LeaveRequest l in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DashboardCard(
                  child: Row(
                    children: <Widget>[
                      UserAvatar(name: l.userName, radius: 20,
                          imageUrl: l.avatarUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    l.userName.isEmpty ? 'Member' : l.userName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _TypeChip(type: l.type),
                              ],
                            ),
                            Text('${_range(l)}  ·  ${l.days} '
                                '${l.days == 1 ? 'day' : 'days'}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant)),
                            if (l.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(l.note,
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.rose,
                          side: const BorderSide(color: AppColors.rose),
                        ),
                        onPressed: () => _decide(context, ref, l.id, false),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _decide(context, ref, l.id, true),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Files a new leave request: type, a date range and an optional note.
class _RequestLeaveDialog extends ConsumerStatefulWidget {
  const _RequestLeaveDialog();

  @override
  ConsumerState<_RequestLeaveDialog> createState() =>
      _RequestLeaveDialogState();
}

class _RequestLeaveDialogState extends ConsumerState<_RequestLeaveDialog> {
  LeaveType _type = LeaveType.vacation;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  final TextEditingController _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final DateTime initial = start ? _start : _end;
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) {
      return;
    }
    setState(() {
      if (start) {
        _start = d;
        if (_end.isBefore(_start)) {
          _end = _start;
        }
      } else {
        _end = d.isBefore(_start) ? _start : d;
      }
    });
  }

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(leaveRepositoryProvider).create(
            type: _type,
            start: DateTime(_start.year, _start.month, _start.day),
            end: DateTime(_end.year, _end.month, _end.day),
            note: _note.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showError('Could not request: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int days = _end.difference(_start).inDays + 1;
    return AlertDialog(
      title: const Text('Request leave'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<LeaveType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: <DropdownMenuItem<LeaveType>>[
                for (final LeaveType t in LeaveType.values)
                  DropdownMenuItem<LeaveType>(
                    value: t,
                    child: Row(
                      children: <Widget>[
                        Icon(t.icon, size: 18, color: t.color),
                        const SizedBox(width: 8),
                        Text(t.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (LeaveType? v) =>
                  setState(() => _type = v ?? LeaveType.vacation),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(start: true),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text('From ${shortDate(_start)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(start: false),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text('To ${shortDate(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('$days ${days == 1 ? 'day' : 'days'}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                isDense: true,
              ),
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
          onPressed: _busy ? null : _save,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
