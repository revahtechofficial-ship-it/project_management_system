import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/enums/project_status.dart';
import '../../data/models/folder.dart';
import '../../data/models/project.dart';
import '../../data/models/project_template.dart';
import '../../data/models/space.dart';
import '../../providers/auth_provider.dart';
import 'providers/project_templates_providers.dart';
import 'providers/projects_providers.dart';
import 'providers/spaces_providers.dart';
import 'widgets/project_form_dialog.dart';

/// The projects board: delivery status, progress and team per project — all
/// backed by the live `/api/v1/projects` API.
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Project>> projectsAsync = ref.watch(projectsProvider);
    final List<Project> projects =
        projectsAsync.asData?.value ?? const <Project>[];
    final int active = projects
        .where((Project p) => p.status == ProjectStatus.active)
        .length;
    final int completed = projects
        .where((Project p) => p.status == ProjectStatus.completed)
        .length;
    final double avg = projects.isEmpty
        ? 0
        : projects.fold<double>(0, (double s, Project p) => s + p.progress) /
              projects.length;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int overdue = projects
        .where(
          (Project p) =>
              p.status != ProjectStatus.completed &&
              p.dueDate != null &&
              p.dueDate!.toLocal().isBefore(today),
        )
        .length;
    final List<Space> spaces =
        ref.watch(spacesProvider).asData?.value ?? const <Space>[];
    final List<Folder> folders =
        ref.watch(foldersProvider).asData?.value ?? const <Folder>[];
    final bool isAdmin =
        ref.watch(authControllerProvider).asData?.value.isAdmin ?? false;
    final List<Project> uncategorized = projects
        .where((Project p) => p.spaceId == null)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        PageHeader(
          title: 'Projects',
          subtitle: 'Track delivery across the team',
          actions: <Widget>[
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(projectsProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            _ProjectTemplatesButton(
              onSelected: (ProjectTemplate t) =>
                  _openForm(context, ref, template: t),
            ),
            if (isAdmin)
              OutlinedButton.icon(
                onPressed: () => _showSpaceDialog(context, ref, null),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('New space'),
              ),
            FilledButton.icon(
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New project'),
            ),
          ],
        ),
        if (projectsAsync.isLoading) const LoadingBar(),
        if (projectsAsync.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ErrorNotice(error: projectsAsync.error!),
          ),
        const SizedBox(height: 20),
        StatCardGrid(
          cards: <Widget>[
            StatCard(
              icon: Icons.folder_rounded,
              color: AppColors.brand,
              label: 'Total projects',
              value: '${projects.length}',
              footer: 'in the workspace',
            ),
            StatCard(
              icon: Icons.bolt_rounded,
              color: AppColors.sky,
              label: 'Active',
              value: '$active',
              footer: 'in progress',
            ),
            StatCard(
              icon: Icons.task_alt_rounded,
              color: AppColors.green,
              label: 'Completed',
              value: '$completed',
              footer: 'delivered',
            ),
            StatCard(
              icon: Icons.donut_large_rounded,
              color: AppColors.teal,
              label: 'Avg. progress',
              value: '${(avg * 100).round()}%',
              progress: avg,
            ),
            StatCard(
              icon: Icons.warning_amber_rounded,
              color: AppColors.rose,
              label: 'Overdue',
              value: '$overdue',
              footer: 'past due date',
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (projects.isEmpty && spaces.isEmpty && !projectsAsync.isLoading)
          const EmptyState(
            icon: Icons.folder_off_rounded,
            message: 'No projects yet. Create your first one.',
          )
        else ...<Widget>[
          for (final Space space in spaces)
            _SpaceSection(
              space: space,
              folders: folders
                  .where((Folder f) => f.spaceId == space.id)
                  .toList(growable: false),
              projects: projects
                  .where((Project p) => p.spaceId == space.id)
                  .toList(growable: false),
              isAdmin: isAdmin,
            ),
          if (uncategorized.isNotEmpty) ...<Widget>[
            const _SectionLabel(
              icon: Icons.inbox_outlined,
              label: 'Uncategorized',
            ),
            const SizedBox(height: 12),
            _ProjectGrid(projects: uncategorized),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

/// A muted section label with an icon, used for spaces / folders headings.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    this.color,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: color ?? scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        if (trailing != null) ...<Widget>[const Spacer(), trailing!],
      ],
    );
  }
}

/// A responsive grid of project cards.
class _ProjectGrid extends StatelessWidget {
  const _ProjectGrid({required this.projects});
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      final ColorScheme scheme = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'No projects here yet.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final int cols = w >= 1080 ? 3 : (w >= 680 ? 2 : 1);
        const double gap = 16;
        final double cardW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Project project in projects)
              SizedBox(
                width: cardW,
                child: _ProjectCard(project: project),
              ),
          ],
        );
      },
    );
  }
}

/// A space heading with its folders and direct projects, plus admin actions.
class _SpaceSection extends ConsumerWidget {
  const _SpaceSection({
    required this.space,
    required this.folders,
    required this.projects,
    required this.isAdmin,
  });

  final Space space;
  final List<Folder> folders;
  final List<Project> projects;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Project> direct = projects
        .where((Project p) => p.folderId == null)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionLabel(
            icon: Icons.workspaces_outline,
            label: space.name,
            color: space.color,
            trailing: isAdmin
                ? PopupMenuButton<String>(
                    tooltip: 'Space actions',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onSelected: (String v) {
                      switch (v) {
                        case 'folder':
                          _showFolderDialog(context, ref, space.id, null);
                        case 'edit':
                          _showSpaceDialog(context, ref, space);
                        case 'delete':
                          _deleteSpace(context, ref, space);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'folder',
                            child: Text('Add folder'),
                          ),
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Rename / recolor'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete space'),
                          ),
                        ],
                  )
                : null,
          ),
          const SizedBox(height: 12),
          for (final Folder folder in folders) ...<Widget>[
            _FolderHeader(folder: folder, isAdmin: isAdmin),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: _ProjectGrid(
                projects: projects
                    .where((Project p) => p.folderId == folder.id)
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _ProjectGrid(projects: direct),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FolderHeader extends ConsumerWidget {
  const _FolderHeader({required this.folder, required this.isAdmin});
  final Folder folder;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        children: <Widget>[
          Icon(Icons.folder_outlined, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            folder.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (isAdmin)
            PopupMenuButton<String>(
              tooltip: 'Folder actions',
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_horiz,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              onSelected: (String v) {
                if (v == 'edit') {
                  _showFolderDialog(context, ref, folder.spaceId, folder);
                } else if (v == 'delete') {
                  _deleteFolder(context, ref, folder);
                }
              },
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'edit', child: Text('Rename')),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
            ),
        ],
      ),
    );
  }
}

Future<void> _showSpaceDialog(
  BuildContext context,
  WidgetRef ref,
  Space? space,
) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => _SpaceDialog(space: space),
  );
}

Future<void> _showFolderDialog(
  BuildContext context,
  WidgetRef ref,
  int spaceId,
  Folder? folder,
) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) =>
        _FolderDialog(spaceId: spaceId, folder: folder),
  );
}

Future<void> _deleteSpace(
  BuildContext context,
  WidgetRef ref,
  Space space,
) async {
  final bool ok =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('Delete "${space.name}"?'),
          content: const Text(
            'Its folders are removed and its projects become '
            'uncategorized. No projects are deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
  if (!ok) {
    return;
  }
  await ref.read(spacesRepositoryProvider).deleteSpace(space.id);
  ref.invalidate(spacesProvider);
  ref.invalidate(foldersProvider);
  ref.invalidate(projectsProvider);
}

Future<void> _deleteFolder(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) async {
  final bool ok =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('Delete "${folder.name}"?'),
          content: const Text(
            'Its projects move directly into the space. None are deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
  if (!ok) {
    return;
  }
  await ref.read(spacesRepositoryProvider).deleteFolder(folder.id);
  ref.invalidate(foldersProvider);
  ref.invalidate(projectsProvider);
}

/// Add / edit a space: a name plus an accent color.
class _SpaceDialog extends ConsumerStatefulWidget {
  const _SpaceDialog({this.space});
  final Space? space;

  @override
  ConsumerState<_SpaceDialog> createState() => _SpaceDialogState();
}

class _SpaceDialogState extends ConsumerState<_SpaceDialog> {
  static const List<String> _palette = <String>[
    '#6366f1',
    '#0ea5e9',
    '#14b8a6',
    '#22c55e',
    '#f59e0b',
    '#ef4444',
    '#ec4899',
    '#8b5cf6',
    '#64748b',
    '#f97316',
  ];

  late final TextEditingController _name = TextEditingController(
    text: widget.space?.name ?? '',
  );
  late String _color = widget.space?.colorHex ?? _palette.first;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(spacesRepositoryProvider);
      if (widget.space != null) {
        await repo.updateSpace(widget.space!.id, name: name, color: _color);
      } else {
        await repo.createSpace(name: name, color: _color);
      }
      ref.invalidate(spacesProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.space == null ? 'New space' : 'Edit space'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Text(
              'Color',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final String hex in _palette)
                  _Swatch(
                    hex: hex,
                    selected: hex == _color,
                    onTap: () => setState(() => _color = hex),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = Space(id: 0, colorHex: hex).color;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}

/// Add / rename a folder inside a space.
class _FolderDialog extends ConsumerStatefulWidget {
  const _FolderDialog({required this.spaceId, this.folder});
  final int spaceId;
  final Folder? folder;

  @override
  ConsumerState<_FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends ConsumerState<_FolderDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.folder?.name ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(spacesRepositoryProvider);
      if (widget.folder != null) {
        await repo.updateFolder(widget.folder!.id, name: name);
      } else {
        await repo.createFolder(spaceId: widget.spaceId, name: name);
      }
      ref.invalidate(foldersProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.folder == null ? 'New folder' : 'Rename folder'),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  Project? project,
  ProjectTemplate? template,
}) async {
  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) =>
        ProjectFormDialog(project: project, template: template),
  );
  if (saved ?? false) {
    ref.invalidate(projectsProvider);
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusPill(
                label: project.status.label,
                color: project.status.color,
              ),
              const SizedBox(width: 6),
              _HealthBadge(project: project),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Project actions',
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_horiz,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                onSelected: (String v) => _onAction(context, ref, v),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  if (ref.watch(authControllerProvider).asData?.value.isAdmin ??
                      false)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 38,
            child: Text(
              project.description.isEmpty
                  ? 'No description'
                  : project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Text(
                '${project.doneTasks}/${project.totalTasks} tasks',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '${(project.progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: project.progress,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: project.status.color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              if (project.memberNames.isEmpty)
                Text(
                  'No members',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                _AvatarStack(names: project.memberNames),
              const Spacer(),
              if (project.dueDate != null) _DueChip(due: project.dueDate!),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    if (action == 'edit') {
      await _openForm(context, ref, project: project);
      return;
    }
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text('"${project.name}" will be permanently removed.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirm ?? false)) {
      return;
    }
    try {
      await ref.read(projectsRepositoryProvider).delete(project.id);
      ref.invalidate(projectsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }
}

/// A "From template" menu shown beside "New project" when templates exist.
class _ProjectTemplatesButton extends ConsumerWidget {
  const _ProjectTemplatesButton({required this.onSelected});
  final ValueChanged<ProjectTemplate> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<ProjectTemplate> templates =
        ref.watch(projectTemplatesProvider).asData?.value ??
        const <ProjectTemplate>[];
    if (templates.isEmpty) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<ProjectTemplate>(
      tooltip: 'New from template',
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<ProjectTemplate>>[
        for (final ProjectTemplate t in templates)
          PopupMenuItem<ProjectTemplate>(value: t, child: Text(t.name)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.bookmark_outline, size: 18),
            SizedBox(width: 8),
            Text('From template'),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// A schedule-health chip (On track / At risk / Overdue) for an open project.
class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    if (project.status == ProjectStatus.completed || project.dueDate == null) {
      return const SizedBox.shrink();
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime due = project.dueDate!.toLocal();
    final String label;
    final Color color;
    if (due.isBefore(today)) {
      label = 'Overdue';
      color = AppColors.rose;
    } else if (due.difference(today).inDays <= 7 && project.progress < 0.9) {
      label = 'At risk';
      color = AppColors.amber;
    } else {
      label = 'On track';
      color = AppColors.teal;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final List<String> shown = names.take(3).toList();
    final int extra = names.length - shown.length;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int count = shown.length + (extra > 0 ? 1 : 0);
    final double width = count == 0 ? 0 : (count - 1) * 20.0 + 30;
    return SizedBox(
      height: 30,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: UserAvatar(name: shown[i], radius: 13),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * 20.0,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Text(
                  '+$extra',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.due});
  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final bool overdue = due.isBefore(today);
    final Color color = overdue ? AppColors.rose : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.event_rounded, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          shortDate(due),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
