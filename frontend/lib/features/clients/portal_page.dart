import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/revah_logo.dart';
import '../../data/models/invoice.dart';
import '../../data/models/portal_data.dart';
import '../../data/models/project.dart';
import 'providers/clients_providers.dart';

/// A public, read-only client portal reached via a portal token. Renders
/// standalone (no app shell) so clients can open it without signing in.
class PortalPage extends ConsumerWidget {
  const PortalPage({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PortalData> async = ref.watch(portalDataProvider(token));
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              const _Header(),
              Expanded(
                child: async.when(
                  loading: () => const LoadingView(),
                  error: (Object e, _) => const _Invalid(),
                  data: (PortalData p) => _Body(data: p),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          const RevahLogo(height: 26),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.handshake_outlined,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Client portal',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
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

class _Body extends StatelessWidget {
  const _Body({required this.data});
  final PortalData data;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              data.heading,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            if (data.clientName.isNotEmpty && data.clientCompany.isNotEmpty)
              Text(
                data.clientName,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: 20),
            if (data.outstandingCents > 0) ...<Widget>[
              _OutstandingBanner(cents: data.outstandingCents),
              const SizedBox(height: 20),
            ],
            Text(
              'Projects',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (data.projects.isEmpty)
              const EmptyState(
                icon: Icons.folder_open_outlined,
                message: 'No projects to show yet.',
              )
            else
              for (final Project p in data.projects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ProjectCard(project: p),
                ),
            const SizedBox(height: 20),
            Text(
              'Invoices',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (data.invoices.isEmpty)
              const EmptyState(
                icon: Icons.request_quote_outlined,
                message: 'No invoices yet.',
              )
            else
              for (final Invoice i in data.invoices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InvoiceCard(invoice: i),
                ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OutstandingBanner extends StatelessWidget {
  const _OutstandingBanner({required this.cents});
  final int cents;

  @override
  Widget build(BuildContext context) {
    const Color amber = Color(0xFFEA580C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.account_balance_outlined, color: amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${formatCents(cents)} outstanding',
              style: const TextStyle(fontWeight: FontWeight.w700, color: amber),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Project p = project;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  p.name.isEmpty ? 'Project' : p.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${(p.progress * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (p.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              p.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.progress,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            <String>[
              '${p.doneTasks} of ${p.totalTasks} tasks done',
              if (p.dueDate case final DateTime d)
                'due ${shortDate(d.toLocal())} ${d.toLocal().year}',
            ].join('  ·  '),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Invoice i = invoice;
    return DashboardCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  i.number,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (i.dueDate case final DateTime d)
                  Text(
                    'Due ${shortDate(d)} ${d.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                formatCents(i.totalCents),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: i.status.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  i.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: i.status.color,
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

class _Invalid extends StatelessWidget {
  const _Invalid();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.link_off_rounded,
      title: 'Portal not available',
      message: 'This portal link is invalid or has been turned off.',
    );
  }
}
