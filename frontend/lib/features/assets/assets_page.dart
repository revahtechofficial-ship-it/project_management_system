import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/enums/asset_kind.dart';
import '../../data/models/asset.dart';
import 'providers/assets_providers.dart';
import 'widgets/asset_form_dialog.dart';

/// Inventory: the company's hardware, software and licenses, who holds them
/// and when they expire.
class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key});

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  AssetKind? _filter;

  Future<void> _add() async {
    await showAssetFormDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Asset>> async = ref.watch(assetsProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Inventory',
            subtitle: 'Hardware, software & licenses',
            actions: <Widget>[
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('New asset'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(assetsProvider),
              ),
              data: (List<Asset> all) => _Body(
                all: all,
                filter: _filter,
                onFilter: (AssetKind? k) => setState(() => _filter = k),
                onAdd: _add,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.all,
    required this.filter,
    required this.onFilter,
    required this.onAdd,
  });

  final List<Asset> all;
  final AssetKind? filter;
  final ValueChanged<AssetKind?> onFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No assets yet',
        message: 'Track laptops, software subscriptions and licenses so you '
            'know what the team holds and when things expire.',
        actionLabel: 'Add the first asset',
        actionIcon: Icons.add,
        onAction: onAdd,
      );
    }
    final List<Asset> items = filter == null
        ? all
        : all.where((Asset a) => a.kind == filter).toList();
    final int totalValue =
        all.fold<int>(0, (int sum, Asset a) => sum + a.costCents);
    final int expiring = all.where((Asset a) => a.expiringSoon).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _Stat(label: '${all.length} items', icon: Icons.inventory_2_outlined),
            _Stat(label: formatCents(totalValue), icon: Icons.payments_outlined),
            if (expiring > 0)
              _Stat(
                label: '$expiring expiring soon',
                icon: Icons.warning_amber_rounded,
                warn: true,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _FilterBar(selected: filter, onSelect: onFilter),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: <Widget>[
                for (final Asset a in items)
                  SizedBox(width: 340, child: _AssetCard(asset: a)),
              ],
            ),
          ),
        ),
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
    final Color color = warn ? const Color(0xFFEA580C) : scheme.onSurfaceVariant;
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
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});
  final AssetKind? selected;
  final ValueChanged<AssetKind?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        ChoiceChip(
          label: const Text('All'),
          selected: selected == null,
          onSelected: (_) => onSelect(null),
        ),
        for (final AssetKind k in AssetKind.values)
          ChoiceChip(
            avatar: Icon(k.icon, size: 16, color: k.color),
            label: Text(k.label),
            selected: selected == k,
            onSelected: (_) => onSelect(k),
          ),
      ],
    );
  }
}

class _AssetCard extends ConsumerWidget {
  const _AssetCard({required this.asset});
  final Asset asset;

  Future<void> _edit(BuildContext context) async {
    await showAssetFormDialog(context, existing: asset);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Delete asset?'),
            content: Text('Remove "${asset.name}" from the inventory?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    try {
      await ref.read(assetsRepositoryProvider).delete(asset.id);
      ref.invalidate(assetsProvider);
      if (context.mounted) {
        context.showSuccess('Asset deleted');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not delete: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: asset.kind.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(asset.kind.icon, size: 20, color: asset.kind.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      asset.vendor.isEmpty ? asset.kind.label : asset.vendor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                icon: const Icon(Icons.more_horiz),
                onSelected: (String v) {
                  switch (v) {
                    case 'edit':
                      _edit(context);
                    case 'delete':
                      _delete(context, ref);
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  PopupMenuItem<String>(
                      value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _StatusChip(asset: asset),
              const Spacer(),
              if (asset.costCents > 0)
                Text(
                  formatCents(asset.costCents),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          if (asset.identifier.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Icon(Icons.tag, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    asset.identifier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ]),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              if (asset.assigneeId != null) ...<Widget>[
                UserAvatar(name: asset.assigneeName, radius: 11),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    asset.assigneeName.isEmpty
                        ? 'Assigned'
                        : asset.assigneeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ] else
                Expanded(
                  child: Text('Unassigned',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
              if (asset.expiresOn case final DateTime e)
                _ExpiryTag(date: e, soon: asset.expiringSoon),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.asset});
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final Color color = asset.status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        asset.status.label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _ExpiryTag extends StatelessWidget {
  const _ExpiryTag({required this.date, required this.soon});
  final DateTime date;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color color =
        soon ? const Color(0xFFEA580C) : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(soon ? Icons.warning_amber_rounded : Icons.event_outlined,
            size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '${shortDate(date)} ${date.year}',
          style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: soon ? FontWeight.w700 : FontWeight.w400),
        ),
      ],
    );
  }
}
