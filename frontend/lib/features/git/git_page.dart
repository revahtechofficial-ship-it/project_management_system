import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_config.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/models/git_commit.dart';
import '../../data/models/git_repo.dart';
import 'providers/git_providers.dart';
import 'widgets/add_repo_dialog.dart';

enum _GitView { repos, activity }

/// Code: registered repositories and the commit activity fed by their push
/// webhooks, with commits auto-linked to tasks by `#id` references.
class GitPage extends ConsumerStatefulWidget {
  const GitPage({super.key});

  @override
  ConsumerState<GitPage> createState() => _GitPageState();
}

class _GitPageState extends ConsumerState<GitPage> {
  _GitView _view = _GitView.repos;

  Future<void> _add() async {
    final bool? added = await showAddRepoDialog(context);
    if (added == true && mounted) {
      setState(() => _view = _GitView.repos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Code',
            subtitle: 'Repositories & commit activity',
            actions: <Widget>[
              SegmentedButton<_GitView>(
                segments: const <ButtonSegment<_GitView>>[
                  ButtonSegment<_GitView>(
                    value: _GitView.repos,
                    icon: Icon(Icons.folder_copy_outlined, size: 18),
                    label: Text('Repositories'),
                  ),
                  ButtonSegment<_GitView>(
                    value: _GitView.activity,
                    icon: Icon(Icons.commit, size: 18),
                    label: Text('Activity'),
                  ),
                ],
                selected: <_GitView>{_view},
                showSelectedIcon: false,
                onSelectionChanged: (Set<_GitView> s) =>
                    setState(() => _view = s.first),
              ),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add repo'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _view == _GitView.repos
                ? _ReposView(onAdd: _add)
                : const _ActivityView(),
          ),
        ],
      ),
    );
  }
}

class _ReposView extends ConsumerWidget {
  const _ReposView({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GitRepo>> async = ref.watch(gitReposProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (Object e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(gitReposProvider),
      ),
      data: (List<GitRepo> repos) {
        if (repos.isEmpty) {
          return EmptyState(
            icon: Icons.folder_copy_outlined,
            title: 'No repositories',
            message: 'Register a repo, then point its push webhook at the '
                'generated URL to stream commits here. Commit messages that '
                'reference #<task id> link automatically.',
            actionLabel: 'Register a repository',
            actionIcon: Icons.add,
            onAction: onAdd,
          );
        }
        return SingleChildScrollView(
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: <Widget>[
              for (final GitRepo repo in repos)
                SizedBox(width: 460, child: _RepoCard(repo: repo)),
            ],
          ),
        );
      },
    );
  }
}

class _RepoCard extends ConsumerWidget {
  const _RepoCard({required this.repo});
  final GitRepo repo;

  String get _webhookUrl =>
      '${AppConfig.apiBaseUrl}/api/v1/git-webhook/${repo.webhookToken}';

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Remove repository?'),
            content: Text('Remove "${repo.name}" and its ingested commits?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    try {
      await ref.read(gitRepositoryProvider).deleteRepo(repo.id);
      ref.invalidate(gitReposProvider);
      ref.invalidate(gitCommitsProvider);
      if (context.mounted) {
        context.showSuccess('Repository removed');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not remove: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<String> meta = <String>[
      if (repo.projectName.isNotEmpty) repo.projectName,
      repo.defaultBranch,
      '${repo.commitCount} commits',
      if (repo.lastCommitAt case final DateTime t)
        'last ${relativeTime(t)}',
    ];
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: repo.provider.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(repo.provider.icon,
                    size: 20, color: repo.provider.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      repo.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      meta.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (repo.url.isNotEmpty)
                IconButton(
                  tooltip: 'Open repository',
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => launchUrl(Uri.parse(repo.url),
                      webOnlyWindowName: '_blank'),
                ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _delete(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WebhookField(url: _webhookUrl),
        ],
      ),
    );
  }
}

/// The copyable push-webhook URL for a repository.
class _WebhookField extends StatelessWidget {
  const _WebhookField({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.webhook_outlined, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy webhook URL',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                context.showSuccess('Webhook URL copied');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityView extends ConsumerWidget {
  const _ActivityView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GitCommit>> async = ref.watch(gitCommitsProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (Object e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(gitCommitsProvider),
      ),
      data: (List<GitCommit> commits) {
        if (commits.isEmpty) {
          return const EmptyState(
            icon: Icons.commit,
            title: 'No commit activity',
            message: 'Once a repository push webhook fires, its commits show '
                'up here newest first.',
          );
        }
        return ListView.separated(
          itemCount: commits.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int i) =>
              _CommitRow(commit: commits[i]),
        );
      },
    );
  }
}

class _CommitRow extends StatelessWidget {
  const _CommitRow({required this.commit});
  final GitCommit commit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final GitCommit c = commit;
    final List<String> meta = <String>[
      if (c.authorName.isNotEmpty) c.authorName,
      c.repoName,
      if (c.branch.isNotEmpty) c.branch,
      relativeTime(c.committedAt),
    ];
    return DashboardCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              c.shortSha,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  c.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  meta.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                if (c.taskRef != null) ...<Widget>[
                  const SizedBox(height: 6),
                  _TaskLinkChip(commit: c),
                ],
              ],
            ),
          ),
          if (c.url.isNotEmpty)
            IconButton(
              tooltip: 'Open commit',
              icon: const Icon(Icons.open_in_new, size: 16),
              onPressed: () =>
                  launchUrl(Uri.parse(c.url), webOnlyWindowName: '_blank'),
            ),
        ],
      ),
    );
  }
}

class _TaskLinkChip extends StatelessWidget {
  const _TaskLinkChip({required this.commit});
  final GitCommit commit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String label = commit.taskTitle.isEmpty
        ? '#${commit.taskRef}'
        : '#${commit.taskRef} · ${commit.taskTitle}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.link, size: 13, color: scheme.primary),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
