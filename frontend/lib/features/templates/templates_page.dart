import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/checklist_template.dart';
import 'providers/checklist_templates_providers.dart';
import 'widgets/checklist_template_form_dialog.dart';

/// Templates gallery: reusable checklists that can be applied to any task or
/// copied into a doc.
class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({super.key});

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  Future<void> _create() async {
    await showChecklistTemplateDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ChecklistTemplate>> async = ref.watch(
      checklistTemplatesProvider,
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Checklist templates',
            subtitle: 'Reusable checklists to apply to tasks',
            actions: <Widget>[
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New checklist'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(checklistTemplatesProvider),
              ),
              data: (List<ChecklistTemplate> templates) {
                if (templates.isEmpty) {
                  return EmptyState(
                    icon: Icons.checklist,
                    title: 'No checklist templates',
                    message:
                        'Save a checklist you reuse — a review checklist, '
                        'onboarding steps — and apply it to any task in one '
                        'click.',
                    actionLabel: 'New checklist',
                    actionIcon: Icons.add,
                    onAction: _create,
                  );
                }
                return _Grouped(templates: templates);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Grouped extends StatelessWidget {
  const _Grouped({required this.templates});
  final List<ChecklistTemplate> templates;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Map<String, List<ChecklistTemplate>> byCategory =
        <String, List<ChecklistTemplate>>{};
    for (final ChecklistTemplate t in templates) {
      final String key = t.category.isEmpty ? 'General' : t.category;
      byCategory.putIfAbsent(key, () => <ChecklistTemplate>[]).add(t);
    }
    final List<String> categories = byCategory.keys.toList()..sort();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String category in categories) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: <Widget>[
                for (final ChecklistTemplate t in byCategory[category]!)
                  SizedBox(width: 340, child: _TemplateCard(template: t)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template});
  final ChecklistTemplate template;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Delete template?'),
            content: Text('Remove "${template.name}"?'),
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
      await ref.read(checklistTemplatesRepositoryProvider).delete(template.id);
      ref.invalidate(checklistTemplatesProvider);
      if (context.mounted) {
        context.showSuccess('Template deleted');
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
    final ChecklistTemplate t = template;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                icon: const Icon(Icons.more_horiz),
                onSelected: (String v) {
                  switch (v) {
                    case 'edit':
                      showChecklistTemplateDialog(context, existing: t);
                    case 'copy':
                      Clipboard.setData(ClipboardData(text: t.asMarkdown));
                      context.showSuccess('Copied as Markdown checklist');
                    case 'delete':
                      _delete(context, ref);
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                      PopupMenuItem<String>(
                        value: 'copy',
                        child: Text('Copy as Markdown'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
              ),
            ],
          ),
          Text(
            '${t.items.length} '
            '${t.items.length == 1 ? 'item' : 'items'}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final String item in t.items.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.check_box_outline_blank,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (t.items.length > 6)
            Text(
              '+${t.items.length - 6} more',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
