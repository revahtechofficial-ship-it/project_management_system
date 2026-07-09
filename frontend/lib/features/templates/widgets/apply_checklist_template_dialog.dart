import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../core/widgets/async_states.dart';
import '../../../data/models/checklist_template.dart';
import '../providers/checklist_templates_providers.dart';

/// Opens a picker to apply a checklist template to a task. Returns the number
/// of items added (null if dismissed).
Future<int?> showApplyChecklistTemplateDialog(
  BuildContext context,
  int taskId,
) {
  return showDialog<int>(
    context: context,
    builder: (BuildContext _) => _ApplyDialog(taskId: taskId),
  );
}

class _ApplyDialog extends ConsumerWidget {
  const _ApplyDialog({required this.taskId});
  final int taskId;

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    ChecklistTemplate t,
  ) async {
    try {
      final int added = await ref
          .read(checklistTemplatesRepositoryProvider)
          .apply(t.id, taskId);
      if (context.mounted) {
        Navigator.of(context).pop(added);
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not apply: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ChecklistTemplate>> async = ref.watch(
      checklistTemplatesProvider,
    );
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: <Widget>[
                  Icon(Icons.playlist_add_check),
                  SizedBox(width: 10),
                  Text(
                    'Apply checklist template',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: async.when(
                loading: () =>
                    const SizedBox(height: 180, child: LoadingView()),
                error: (Object e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorNotice(error: e),
                ),
                data: (List<ChecklistTemplate> templates) {
                  if (templates.isEmpty) {
                    return const EmptyState(
                      icon: Icons.checklist,
                      title: 'No templates yet',
                      message:
                          'Create checklist templates from the Checklists '
                          'page, then apply them here.',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: templates.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int i) {
                      final ChecklistTemplate t = templates[i];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        leading: const Icon(Icons.checklist),
                        title: Text(t.name),
                        subtitle: Text(
                          <String>[
                            if (t.category.isNotEmpty) t.category,
                            '${t.items.length} items',
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.add),
                        onTap: () => _apply(context, ref, t),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
