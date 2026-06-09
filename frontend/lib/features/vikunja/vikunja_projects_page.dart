import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/vikunja_project.dart';
import '../../providers/auth_provider.dart';
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
      appBar: AppBar(title: const Text('Nexax · Vikunja Projects')),
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
class _NotConnected extends ConsumerWidget {
  const _NotConnected({required this.error});

  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load Vikunja projects.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
          FilledButton.icon(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).connectVikunja(),
            icon: const Icon(Icons.link),
            label: const Text('Connect Vikunja'),
          ),
        ],
      ),
    );
  }
}
