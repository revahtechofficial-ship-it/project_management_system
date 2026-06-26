import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/enums/issue_type.dart';
import '../../../data/enums/task_priority.dart';
import '../../../data/models/saved_filter.dart';
import '../../../data/models/task.dart';
import '../../../data/models/workflow_status.dart';
import '../providers/saved_filters_providers.dart';
import '../providers/statuses_providers.dart';

/// An immutable set of task-list filter criteria. Persisted as a saved filter
/// config and applied client-side to the task list.
class TaskFilter {
  final Set<String> statusKeys;
  final Set<String> priorities;
  final Set<String> issueTypes;
  final bool hideDone;

  const TaskFilter({
    this.statusKeys = const <String>{},
    this.priorities = const <String>{},
    this.issueTypes = const <String>{},
    this.hideDone = false,
  });

  bool get isEmpty =>
      statusKeys.isEmpty &&
      priorities.isEmpty &&
      issueTypes.isEmpty &&
      !hideDone;

  int get activeCount =>
      statusKeys.length +
      priorities.length +
      issueTypes.length +
      (hideDone ? 1 : 0);

  bool matches(Task t) {
    if (hideDone && t.done) {
      return false;
    }
    if (statusKeys.isNotEmpty && !statusKeys.contains(t.statusKey)) {
      return false;
    }
    if (priorities.isNotEmpty && !priorities.contains(t.priority.toJson())) {
      return false;
    }
    if (issueTypes.isNotEmpty && !issueTypes.contains(t.issueType.toJson())) {
      return false;
    }
    return true;
  }

  List<Task> apply(List<Task> tasks) =>
      isEmpty ? tasks : tasks.where(matches).toList(growable: false);

  TaskFilter copyWith({
    Set<String>? statusKeys,
    Set<String>? priorities,
    Set<String>? issueTypes,
    bool? hideDone,
  }) => TaskFilter(
    statusKeys: statusKeys ?? this.statusKeys,
    priorities: priorities ?? this.priorities,
    issueTypes: issueTypes ?? this.issueTypes,
    hideDone: hideDone ?? this.hideDone,
  );

  Map<String, dynamic> toConfig() => <String, dynamic>{
    'statuses': statusKeys.toList(),
    'priorities': priorities.toList(),
    'issue_types': issueTypes.toList(),
    'hide_done': hideDone,
  };

  factory TaskFilter.fromConfig(Map<String, dynamic> c) => TaskFilter(
    statusKeys: <String>{
      for (final dynamic e in c['statuses'] as List<dynamic>? ?? <dynamic>[])
        '$e',
    },
    priorities: <String>{
      for (final dynamic e in c['priorities'] as List<dynamic>? ?? <dynamic>[])
        '$e',
    },
    issueTypes: <String>{
      for (final dynamic e in c['issue_types'] as List<dynamic>? ?? <dynamic>[])
        '$e',
    },
    hideDone: c['hide_done'] as bool? ?? false,
  );
}

/// A popup that edits the active [TaskFilter] (statuses, priorities, hide done).
class TaskFilterButton extends ConsumerWidget {
  const TaskFilterButton({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final TaskFilter filter;
  final ValueChanged<TaskFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<WorkflowStatus> statuses =
        ref.watch(statusesProvider).asData?.value ?? WorkflowStatus.defaults;
    final int active = filter.activeCount;
    return MenuAnchor(
      menuChildren: <Widget>[
        _header('Status'),
        for (final WorkflowStatus s in statuses)
          _check(
            label: s.label,
            value: filter.statusKeys.contains(s.key),
            onChanged: (bool v) {
              final Set<String> next = <String>{...filter.statusKeys};
              v ? next.add(s.key) : next.remove(s.key);
              onChanged(filter.copyWith(statusKeys: next));
            },
          ),
        const Divider(height: 1),
        _header('Type'),
        for (final IssueType it in IssueType.values)
          _check(
            label: it.label,
            value: filter.issueTypes.contains(it.toJson()),
            onChanged: (bool v) {
              final Set<String> next = <String>{...filter.issueTypes};
              v ? next.add(it.toJson()) : next.remove(it.toJson());
              onChanged(filter.copyWith(issueTypes: next));
            },
          ),
        const Divider(height: 1),
        _header('Priority'),
        for (final TaskPriority p in TaskPriority.values)
          _check(
            label: p.label,
            value: filter.priorities.contains(p.toJson()),
            onChanged: (bool v) {
              final Set<String> next = <String>{...filter.priorities};
              v ? next.add(p.toJson()) : next.remove(p.toJson());
              onChanged(filter.copyWith(priorities: next));
            },
          ),
        const Divider(height: 1),
        _check(
          label: 'Hide completed',
          value: filter.hideDone,
          onChanged: (bool v) => onChanged(filter.copyWith(hideDone: v)),
        ),
        if (active > 0)
          MenuItemButton(
            leadingIcon: const Icon(Icons.clear_all, size: 18),
            onPressed: () => onChanged(const TaskFilter()),
            child: const Text('Clear filters'),
          ),
      ],
      builder: (BuildContext context, MenuController controller, Widget? _) {
        return OutlinedButton.icon(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.filter_list, size: 18),
          label: Text(active == 0 ? 'Filter' : 'Filter · $active'),
        );
      },
    );
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _check({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      width: 220,
      child: CheckboxListTile(
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        value: value,
        title: Text(label),
        onChanged: (bool? v) => onChanged(v ?? false),
      ),
    );
  }
}

/// A popup listing saved filters: apply one, save the current filter, or
/// delete saved ones.
class SavedFiltersButton extends ConsumerWidget {
  const SavedFiltersButton({
    super.key,
    required this.current,
    required this.onApply,
  });

  final TaskFilter current;
  final ValueChanged<TaskFilter> onApply;

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final TextEditingController name = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Save filter'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Filter name'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if ((ok ?? false) && name.text.trim().isNotEmpty) {
      await ref
          .read(savedFiltersRepositoryProvider)
          .create(name.text.trim(), current.toConfig());
      ref.invalidate(savedFiltersProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SavedFilter> saved =
        ref.watch(savedFiltersProvider).asData?.value ?? const <SavedFilter>[];
    return MenuAnchor(
      menuChildren: <Widget>[
        for (final SavedFilter f in saved)
          MenuItemButton(
            leadingIcon: const Icon(Icons.bookmark_outline, size: 18),
            trailingIcon: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () async {
                await ref.read(savedFiltersRepositoryProvider).delete(f.id);
                ref.invalidate(savedFiltersProvider);
              },
            ),
            onPressed: () => onApply(TaskFilter.fromConfig(f.config)),
            child: Text(f.name),
          ),
        if (saved.isNotEmpty) const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.add, size: 18),
          onPressed:
              current.isEmpty ? null : () => _save(context, ref),
          child: const Text('Save current filter'),
        ),
      ],
      builder: (BuildContext context, MenuController controller, Widget? _) {
        return IconButton(
          tooltip: 'Saved filters',
          icon: const Icon(Icons.bookmarks_outlined),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        );
      },
    );
  }
}
