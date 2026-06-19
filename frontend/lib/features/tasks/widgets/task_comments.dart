import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/enums/task_status.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/comment.dart';
import '../../../data/models/team_member.dart';
import '../../../providers/auth_provider.dart';
import '../../notifications/providers/notifications_providers.dart';
import '../../team/providers/team_providers.dart';
import '../providers/comments_providers.dart';

final RegExp _mentionRe = RegExp(r'@([A-Za-z0-9._-]+)');

/// Maps lowercased mention tokens (first name, email local-part) to member ids.
Map<String, int> _tokenMap(List<TeamMember> members) {
  final Map<String, int> map = <String, int>{};
  for (final TeamMember m in members) {
    final List<String> parts = m.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) {
      map.putIfAbsent(parts.first.toLowerCase(), () => m.id);
    }
    final String local = m.email.split('@').first.toLowerCase();
    if (local.isNotEmpty) {
      map.putIfAbsent(local, () => m.id);
    }
  }
  return map;
}

List<int> _parseMentions(String body, Map<String, int> tokens) {
  final Set<int> ids = <int>{};
  for (final RegExpMatch m in _mentionRe.allMatches(body)) {
    final int? id = tokens[m.group(1)!.toLowerCase()];
    if (id != null) {
      ids.add(id);
    }
  }
  return ids.toList();
}

List<InlineSpan> _bodySpans(String body, Set<String> valid, Color color) {
  final List<InlineSpan> spans = <InlineSpan>[];
  int last = 0;
  for (final RegExpMatch m in _mentionRe.allMatches(body)) {
    if (m.start > last) {
      spans.add(TextSpan(text: body.substring(last, m.start)));
    }
    final String text = body.substring(m.start, m.end);
    if (valid.contains(m.group(1)!.toLowerCase())) {
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      );
    } else {
      spans.add(TextSpan(text: text));
    }
    last = m.end;
  }
  if (last < body.length) {
    spans.add(TextSpan(text: body.substring(last)));
  }
  return spans;
}

/// The comment thread for a task: list + composer with @mention support.
class TaskCommentsSection extends ConsumerStatefulWidget {
  const TaskCommentsSection({super.key, required this.taskId});
  final int taskId;

  @override
  ConsumerState<TaskCommentsSection> createState() =>
      _TaskCommentsSectionState();
}

class _TaskCommentsSectionState extends ConsumerState<TaskCommentsSection> {
  final TextEditingController _input = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(Map<String, int> tokens) async {
    final String body = _input.text.trim();
    if (body.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    final List<int> mentions = _parseMentions(body, tokens);
    await ref
        .read(commentsRepositoryProvider)
        .add(widget.taskId, body, mentions);
    _input.clear();
    setState(() => _busy = false);
    ref.invalidate(commentsProvider(widget.taskId));
    ref.invalidate(activityProvider(widget.taskId));
    if (mentions.isNotEmpty) {
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    }
  }

  Future<void> _delete(int id) async {
    await ref.read(commentsRepositoryProvider).delete(id);
    ref.invalidate(commentsProvider(widget.taskId));
    ref.invalidate(activityProvider(widget.taskId));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Comment> comments =
        ref.watch(commentsProvider(widget.taskId)).asData?.value ??
        const <Comment>[];
    final List<TeamMember> members =
        ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    final Map<String, int> tokens = _tokenMap(members);
    final Set<String> valid = tokens.keys.toSet();
    final int? me = ref.watch(authControllerProvider).asData?.value.user?.id;
    final bool admin =
        ref.watch(authControllerProvider).asData?.value.isAdmin ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (comments.isEmpty)
          Text(
            'No comments yet — start the conversation.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        for (final Comment c in comments)
          _CommentTile(
            comment: c,
            valid: valid,
            canDelete: admin || (me != null && c.authorId == me),
            onDelete: () => _delete(c.id),
          ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write a comment… use @ to mention',
                  isDense: true,
                ),
                onSubmitted: (_) => _send(tokens),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              onPressed: _busy ? null : () => _send(tokens),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.valid,
    required this.canDelete,
    required this.onDelete,
  });

  final Comment comment;
  final Set<String> valid;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UserAvatar(name: comment.authorName ?? '', radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      comment.authorName ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      relativeTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (canDelete)
                      InkWell(
                        onTap: onDelete,
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: scheme.onSurface,
                    ),
                    children: _bodySpans(comment.body, valid, AppColors.brand),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The read-only activity timeline for a task.
class TaskActivitySection extends ConsumerWidget {
  const TaskActivitySection({super.key, required this.taskId});
  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Activity> items =
        ref.watch(activityProvider(taskId)).asData?.value ?? const <Activity>[];
    if (items.isEmpty) {
      return Text(
        'No activity yet.',
        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final Activity a in items) _ActivityRow(activity: a),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});
  final Activity activity;

  (IconData, Color) get _visual => switch (activity.action) {
    'created' => (Icons.add_circle_rounded, AppColors.brand),
    'completed' => (Icons.check_circle_rounded, AppColors.green),
    'reopened' => (Icons.replay_rounded, AppColors.orange),
    'status' => (Icons.swap_horiz_rounded, AppColors.sky),
    'comment' => (Icons.chat_bubble_rounded, AppColors.brand),
    'updated' => (Icons.edit_rounded, AppColors.slate),
    _ => (Icons.circle, AppColors.slate),
  };

  String get _verb => switch (activity.action) {
    'created' => 'created this task',
    'completed' => 'completed this task',
    'reopened' => 'reopened this task',
    'status' => 'moved to ${TaskStatus.fromJson(activity.detail).label}',
    'comment' => 'commented',
    'updated' => 'edited this task',
    _ => activity.action,
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = _visual;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
                children: <InlineSpan>[
                  TextSpan(
                    text: activity.actorName ?? 'Someone',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' $_verb'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            relativeTime(activity.createdAt),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
