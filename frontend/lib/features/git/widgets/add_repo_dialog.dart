import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../data/enums/git_provider.dart';
import '../../../data/models/project.dart';
import '../../projects/providers/projects_providers.dart';
import '../providers/git_providers.dart';

/// Opens the register-repository dialog. Returns true when a repo was added.
Future<bool?> showAddRepoDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) => const _AddRepoDialog(),
  );
}

class _AddRepoDialog extends ConsumerStatefulWidget {
  const _AddRepoDialog();

  @override
  ConsumerState<_AddRepoDialog> createState() => _AddRepoDialogState();
}

class _AddRepoDialogState extends ConsumerState<_AddRepoDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _branch = TextEditingController(text: 'main');
  GitProvider _provider = GitProvider.github;
  int? _projectId;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _branch.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _busy) {
      context.showError('A repository name is required');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(gitRepositoryProvider).createRepo(
            name: _name.text.trim(),
            provider: _provider.toJson(),
            url: _url.text.trim(),
            defaultBranch: _branch.text.trim().isEmpty
                ? 'main'
                : _branch.text.trim(),
            projectId: _projectId,
          );
      ref.invalidate(gitReposProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showError('Could not add: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Project> projects =
        ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    return AlertDialog(
      title: const Text('Register repository'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Repository',
                hintText: 'org/repo',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GitProvider>(
              initialValue: _provider,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Provider', isDense: true),
              items: <DropdownMenuItem<GitProvider>>[
                for (final GitProvider p in GitProvider.values)
                  DropdownMenuItem<GitProvider>(
                    value: p,
                    child: Text(p.label),
                  ),
              ],
              onChanged: (GitProvider? v) =>
                  setState(() => _provider = v ?? _provider),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL (optional)',
                hintText: 'https://github.com/org/repo',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _branch,
              decoration: const InputDecoration(
                  labelText: 'Default branch', isDense: true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _projectId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Project (optional)', isDense: true),
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(child: Text('No project')),
                for (final Project p in projects)
                  DropdownMenuItem<int?>(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (int? v) => setState(() => _projectId = v),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Register'),
        ),
      ],
    );
  }
}
