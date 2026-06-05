import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tasks_providers.dart';

/// Demo screen that lists tasks from the backend, proving the
/// Riverpod -> Dio -> Go API -> Postgres pipeline end to end.
class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nexax · Tasks')),
      body: tasks.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('No tasks yet.'))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final t = items[i];
                  return CheckboxListTile(
                    value: t.done,
                    onChanged: (v) async {
                      await ref
                          .read(tasksRepositoryProvider)
                          .setDone(t.id, done: v ?? false);
                      ref.invalidate(tasksProvider);
                    },
                    title: Text(t.title),
                    subtitle:
                        t.description.isEmpty ? null : Text(t.description),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load tasks:\n$err',
                textAlign: TextAlign.center),
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
