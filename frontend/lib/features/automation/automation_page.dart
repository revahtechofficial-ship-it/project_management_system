import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/enums/task_priority.dart';
import '../../data/models/automation_rule.dart';
import '../../data/models/project.dart';
import '../../data/models/sprint.dart';
import '../../data/models/team_member.dart';
import '../../data/models/workflow_status.dart';
import '../projects/providers/projects_providers.dart';
import '../sprints/providers/sprints_providers.dart';
import '../tasks/providers/statuses_providers.dart';
import '../team/providers/team_providers.dart';
import 'providers/automations_providers.dart';
import 'widgets/automation_builder.dart';

/// Rule-based automation: when a trigger fires and conditions match, run
/// actions on the task. The builder lives in [showAutomationBuilder]
/// (AGENTS.md §1 feature page).
class AutomationPage extends ConsumerWidget {
  const AutomationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AutomationRule>> async = ref.watch(
      automationsProvider,
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Automation',
            subtitle: 'Rules that run when tasks change',
            actions: <Widget>[
              FilledButton.icon(
                onPressed: () => showAutomationBuilder(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New rule'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (Object e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(automationsProvider),
              ),
              data: (List<AutomationRule> rules) {
                if (rules.isEmpty) {
                  return const EmptyState(
                    icon: Icons.bolt_outlined,
                    message:
                        'No automations yet. Create a rule to save manual work.',
                  );
                }
                return ListView.separated(
                  itemCount: rules.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int i) =>
                      _RuleCard(rule: rules[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.rule});

  final AutomationRule rule;

  static const Map<String, String> _triggerLabels = <String, String>{
    'task_created': 'a task is created',
    'status_changed': 'the status changes',
    'task_completed': 'a task is completed',
    'assignee_changed': 'the assignee changes',
  };

  Future<void> _toggle(WidgetRef ref, bool on) async {
    await ref.read(automationsRepositoryProvider).setEnabled(rule.id, on);
    ref.invalidate(automationsProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok = await confirmDelete(
      context,
      what: '"${rule.name}"',
      message: 'This automation rule will be removed.',
    );
    if (!ok) {
      return;
    }
    await ref.read(automationsRepositoryProvider).delete(rule.id);
    ref.invalidate(automationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.bolt,
                color: rule.enabled ? AppColors.amber : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rule.name.isEmpty ? 'Untitled rule' : rule.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(
                value: rule.enabled,
                onChanged: (bool v) => _toggle(ref, v),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                onSelected: (String v) {
                  if (v == 'edit') {
                    showAutomationBuilder(context, existing: rule);
                  } else if (v == 'delete') {
                    _delete(context, ref);
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _line(context, 'When', _triggerLabels[rule.trigger] ?? rule.trigger),
          for (final RuleCondition c in rule.conditions)
            _line(
              context,
              'If',
              '${_fieldLabel(c.field)} ${c.op == 'is_not' ? 'is not' : 'is'} '
                  '${_describe(ref, condKind(c.field), c.value)}',
            ),
          for (final RuleAction a in rule.actions)
            _line(
              context,
              'Then',
              '${_actionLabel(a.type)}'
                  '${actKind(a.type) == 'none' ? '' : ' ${_describe(ref, actKind(a.type), a.value)}'}',
            ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String tag, String text) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  String _fieldLabel(String field) {
    for (final (String, String) f in kFields) {
      if (f.$1 == field) {
        return f.$2;
      }
    }
    return field;
  }

  String _actionLabel(String type) {
    for (final (String, String) a in kActions) {
      if (a.$1 == type) {
        return a.$2;
      }
    }
    return type;
  }

  String _describe(WidgetRef ref, String kind, String value) {
    switch (kind) {
      case 'status':
        final List<WorkflowStatus> s =
            ref.watch(statusesProvider).asData?.value ??
            WorkflowStatus.defaults;
        return WorkflowStatus.forKey(s, value).label;
      case 'priority':
        return TaskPriority.fromJson(value).label;
      case 'project':
        final List<Project> p =
            ref.watch(projectsProvider).asData?.value ?? const <Project>[];
        for (final Project x in p) {
          if ('${x.id}' == value) {
            return x.name;
          }
        }
        return 'a project';
      case 'sprint':
        final List<Sprint> sp =
            ref.watch(sprintsProvider).asData?.value ?? const <Sprint>[];
        for (final Sprint x in sp) {
          if ('${x.id}' == value) {
            return x.name;
          }
        }
        return 'a sprint';
      case 'user':
        final List<TeamMember> t =
            ref.watch(teamMembersProvider).asData?.value ??
            const <TeamMember>[];
        for (final TeamMember m in t) {
          if ('${m.id}' == value) {
            return m.name.isEmpty ? m.email : m.name;
          }
        }
        return 'someone';
      case 'yesno':
        return value == 'yes' ? 'Yes' : 'No';
      case 'number':
        return '$value days';
      default:
        return value;
    }
  }
}
