import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/digest_data.dart';
import '../../data/repositories/digest_repository.dart';
import 'providers/digest_providers.dart';

/// Digest: a personal summary of unread notifications and tasks due soon or
/// overdue, with a button to email it to yourself.
class DigestPage extends ConsumerStatefulWidget {
  const DigestPage({super.key});

  @override
  ConsumerState<DigestPage> createState() => _DigestPageState();
}

class _DigestPageState extends ConsumerState<DigestPage> {
  bool _emailing = false;

  Future<void> _email() async {
    setState(() => _emailing = true);
    try {
      final DigestEmailResult r = await ref
          .read(digestRepositoryProvider)
          .emailToMe();
      if (mounted) {
        if (r.sent) {
          context.showSuccess('Digest emailed to you');
        } else {
          context.showError(
            r.reason.isEmpty
                ? 'Could not email the digest'
                : 'Not emailed — ${r.reason}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        context.showError('Could not email: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _emailing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DigestData> async = ref.watch(digestProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Digest',
            subtitle: 'Your unread notifications and what\'s due',
            actions: <Widget>[
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(digestProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: _emailing ? null : _email,
                icon: const Icon(Icons.mail_outline, size: 18),
                label: const Text('Email to me'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(digestProvider),
              ),
              data: (DigestData d) {
                if (d.isEmpty) {
                  return const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'You\'re all caught up',
                    message:
                        'No unread notifications and nothing overdue or '
                        'due this week.',
                  );
                }
                return _Body(digest: d);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.digest});
  final DigestData digest;

  @override
  Widget build(BuildContext context) {
    final DigestData d = digest;
    return ListView(
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _Stat(
              label: '${d.unreadCount} unread',
              icon: Icons.notifications_none,
            ),
            _Stat(
              label: '${d.overdue.length} overdue',
              icon: Icons.warning_amber_rounded,
              warn: d.overdue.isNotEmpty,
            ),
            _Stat(
              label: '${d.upcoming.length} due this week',
              icon: Icons.event_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (d.overdue.isNotEmpty) ...<Widget>[
          _TaskCard(title: 'Overdue', tasks: d.overdue, overdue: true),
          const SizedBox(height: 12),
        ],
        if (d.upcoming.isNotEmpty) ...<Widget>[
          _TaskCard(title: 'Due this week', tasks: d.upcoming, overdue: false),
          const SizedBox(height: 12),
        ],
        if (d.notifications.isNotEmpty)
          _NotificationsCard(items: d.notifications),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.icon, this.warn = false});
  final String label;
  final IconData icon;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color = warn
        ? const Color(0xFFEA580C)
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: warn
            ? const Color(0xFFEA580C).withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.title,
    required this.tasks,
    required this.overdue,
  });
  final String title;
  final List<DigestTask> tasks;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      title: title,
      child: Column(
        children: <Widget>[
          for (final DigestTask t in tasks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.radio_button_unchecked,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${shortDate(t.dueDate.toLocal())} '
                    '${t.dueDate.toLocal().year}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: overdue ? AppColors.rose : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({required this.items});
  final List<DigestNotification> items;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      title: 'Unread notifications',
      child: Column(
        children: <Widget>[
          for (final DigestNotification n in items)
            InkWell(
              onTap: n.link.isEmpty ? null : () => context.go(n.link),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.circle, size: 8, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            n.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (n.body.isNotEmpty)
                            Text(
                              n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      relativeTime(n.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
