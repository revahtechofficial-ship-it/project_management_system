import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/saved_dashboard.dart';
import 'providers/dashboards_providers.dart';
import 'widgets/dashboard_builder_dialog.dart';
import 'widgets/saved_dashboard_screen.dart';

/// Lists saved, shareable dashboards and lets the user create new ones
/// (AGENTS.md §1 feature page).
class DashboardsPage extends ConsumerWidget {
  const DashboardsPage({super.key});

  Future<void> _open(BuildContext context, SavedDashboard d) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SavedDashboardScreen(dashboard: d),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final SavedDashboard? created = await showDashboardBuilder(context);
    if (created != null && context.mounted) {
      await _open(context, created);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SavedDashboard>> async = ref.watch(
      savedDashboardsProvider,
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Dashboards',
            subtitle: 'Saved views you can share with the team',
            actions: <Widget>[
              FilledButton.icon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New dashboard'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(savedDashboardsProvider),
              ),
              data: (List<SavedDashboard> items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.dashboard_customize_outlined,
                    message: 'No dashboards yet. Create your first one.',
                  );
                }
                return GridView.extent(
                  maxCrossAxisExtent: 360,
                  childAspectRatio: 1.9,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: <Widget>[
                    for (final SavedDashboard d in items)
                      _DashboardCard(
                        dashboard: d,
                        onTap: () => _open(context, d),
                      ),
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

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.dashboard, required this.onTap});

  final SavedDashboard dashboard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int count = dashboard.widgets.length;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: AppColors.brand.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.space_dashboard_outlined,
                      color: AppColors.brand,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    dashboard.isPrivate
                        ? Icons.lock_outline
                        : Icons.groups_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                dashboard.name.isEmpty ? 'Untitled' : dashboard.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count widget${count == 1 ? '' : 's'}'
                '${dashboard.ownerName.isEmpty ? '' : ' · ${dashboard.ownerName}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
