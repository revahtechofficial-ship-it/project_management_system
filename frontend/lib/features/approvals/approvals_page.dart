import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/approval.dart';
import 'providers/approvals_providers.dart';
import 'widgets/request_approval_dialog.dart';

enum _ApprovalsView { awaiting, mine }

/// Approvals: sign-off requests awaiting you, and the requests you've made
/// (AGENTS.md §1 feature page).
class ApprovalsPage extends ConsumerStatefulWidget {
  const ApprovalsPage({super.key});

  @override
  ConsumerState<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends ConsumerState<ApprovalsPage> {
  _ApprovalsView _view = _ApprovalsView.awaiting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Approvals',
            subtitle: 'Sign-off on tasks, docs and releases',
            actions: <Widget>[
              SegmentedButton<_ApprovalsView>(
                segments: const <ButtonSegment<_ApprovalsView>>[
                  ButtonSegment<_ApprovalsView>(
                    value: _ApprovalsView.awaiting,
                    icon: Icon(Icons.inbox_outlined, size: 18),
                    label: Text('Awaiting you'),
                  ),
                  ButtonSegment<_ApprovalsView>(
                    value: _ApprovalsView.mine,
                    icon: Icon(Icons.send_outlined, size: 18),
                    label: Text('Your requests'),
                  ),
                ],
                selected: <_ApprovalsView>{_view},
                showSelectedIcon: false,
                onSelectionChanged: (Set<_ApprovalsView> s) =>
                    setState(() => _view = s.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _view == _ApprovalsView.awaiting
                ? const _AwaitingView()
                : const _MineView(),
          ),
        ],
      ),
    );
  }
}

class _AwaitingView extends ConsumerWidget {
  const _AwaitingView();

  Future<void> _decide(
      BuildContext context, WidgetRef ref, int id, bool approved) async {
    try {
      await ref
          .read(approvalsRepositoryProvider)
          .decide(id, approved: approved);
      ref.invalidate(pendingApprovalsProvider);
      if (context.mounted) {
        context.showSuccess(approved ? 'Approved' : 'Rejected');
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
    final AsyncValue<List<Approval>> async =
        ref.watch(pendingApprovalsProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (Object e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(pendingApprovalsProvider),
      ),
      data: (List<Approval> items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.verified_outlined,
            title: 'Nothing to approve',
            message: 'Requests that need your sign-off will appear here.',
          );
        }
        return ListView(
          children: <Widget>[
            for (final Approval a in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DashboardCard(
                  child: Row(
                    children: <Widget>[
                      UserAvatar(name: a.requesterName, radius: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              a.subjectTitle.isEmpty
                                  ? '${a.subjectType} #${a.subjectId}'
                                  : a.subjectTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${a.subjectType} · from '
                              '${a.requesterName.isEmpty ? 'a teammate' : a.requesterName}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant),
                            ),
                            if (a.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(a.note,
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE11D48),
                          side: const BorderSide(color: Color(0xFFE11D48)),
                        ),
                        onPressed: () => _decide(context, ref, a.id, false),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _decide(context, ref, a.id, true),
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

class _MineView extends ConsumerWidget {
  const _MineView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<Approval>> async =
        ref.watch(myApprovalRequestsProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (Object e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(myApprovalRequestsProvider),
      ),
      data: (List<Approval> items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.send_outlined,
            title: 'No requests yet',
            message: 'Request approval from a task, doc or release and it will '
                'show up here.',
          );
        }
        return ListView(
          children: <Widget>[
            for (final Approval a in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DashboardCard(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              a.subjectTitle.isEmpty
                                  ? '${a.subjectType} #${a.subjectId}'
                                  : a.subjectTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${a.subjectType} · '
                              '${a.approverName.isEmpty ? 'approver' : a.approverName}'
                              ' · ${relativeTime(a.createdAt)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ApprovalStatusChip(status: a.status),
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
