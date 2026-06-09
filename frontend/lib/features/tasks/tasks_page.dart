import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/task.dart';
import '../../providers/auth_provider.dart';
import 'providers/tasks_providers.dart';

/// Lists tasks from the backend, proving the
/// Riverpod -> Dio -> Go API -> Postgres pipeline (AGENTS.md §1 feature page).
class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> tasks = ref.watch(tasksProvider);
    final String username =
        ref.watch(authControllerProvider).asData?.value.username ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexax · Tasks'),
        actions: <Widget>[
          if (username.isNotEmpty)
            Center(child: Text(username)),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: tasks.when(
        data: (List<Task> items) => items.isEmpty
            ? const Center(child: Text('No tasks yet.'))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (BuildContext context, int i) =>
                    _TaskTile(task: items[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load tasks:\n$err',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.invalidate(tasksProvider),
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

/// A single task row. Private `Widget` class instead of a helper method that
/// returns a `Widget` (AGENTS.md §7).
class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CheckboxListTile(
      value: task.done,
      title: Text(task.title),
      subtitle: task.description.isEmpty ? null : Text(task.description),
      onChanged: (bool? value) async {
        await ref
            .read(tasksRepositoryProvider)
            .setDone(task.id, done: value ?? false);
        ref.invalidate(tasksProvider);
      },
    );
  }
}
