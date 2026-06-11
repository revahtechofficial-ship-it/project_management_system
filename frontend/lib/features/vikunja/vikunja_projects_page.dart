import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/vikunja_project.dart';
import 'providers/vikunja_providers.dart';

/// Lists the user's Vikunja projects through the BFF — the end-to-end proof of
/// the per-user SSO bridge (AGENTS.md §1 feature page).
class VikunjaProjectsPage extends ConsumerWidget {
  const VikunjaProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<VikunjaProject>> projects =
        ref.watch(vikunjaProjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Revah · Vikunja Projects')),
      body: projects.when(
        data: (List<VikunjaProject> items) => items.isEmpty
            ? const Center(child: Text('No projects.'))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (BuildContext context, int i) {
                  final VikunjaProject p = items[i];
                  return ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(p.title),
                    subtitle:
                        p.description.isEmpty ? null : Text(p.description),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, _) => _NotConnected(error: '$err'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.invalidate(vikunjaProjectsProvider),
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

/// Shown when the Vikunja session isn't established (e.g. the BFF returned 428);
/// offers to re-run the silent handshake.
class _NotConnected extends StatelessWidget {
  const _NotConnected({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Vikunja is being reconnected to the new sign-in system.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
