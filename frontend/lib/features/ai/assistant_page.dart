import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/markdown_view.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/project.dart';
import '../../data/repositories/ai_repository.dart';
import '../../providers/auth_provider.dart';
import '../projects/providers/projects_providers.dart';
import '../tasks/providers/tasks_providers.dart';
import 'providers/ai_providers.dart';
import 'widgets/ai_dialogs.dart';

/// A chat turn in the assistant conversation.
class _Turn {
  const _Turn({required this.role, required this.text});
  final String role; // 'user' | 'assistant'
  final String text;
}

/// The AI assistant: a Claude-powered chat plus quick actions (create tasks,
/// summarize, meeting notes, writing help, knowledge search). AGENTS.md §1.
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final List<_Turn> _turns = <_Turn>[];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _add(String role, String text) {
    setState(() => _turns.add(_Turn(role: role, text: text)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _busy) {
      return;
    }
    _input.clear();
    _add('user', text);
    setState(() => _busy = true);
    try {
      final List<Map<String, String>> history = <Map<String, String>>[
        for (final _Turn t in _turns)
          <String, String>{'role': t.role, 'content': t.text},
      ];
      final String reply = await ref.read(aiRepositoryProvider).chat(history);
      _add('assistant', reply);
    } catch (e) {
      _add('assistant', '⚠️ ${_friendly(e)}');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _friendly(Object e) {
    if (e is DioException) {
      final Object? data = e.response?.data;
      if (data is Map && data['error'] is String) {
        final String msg = data['error'] as String;
        if (msg.isNotEmpty) {
          return msg;
        }
      }
    }
    return 'The AI service is unavailable. Make sure ANTHROPIC_API_KEY is set '
        'on the backend and the account has API credits.';
  }

  Future<void> _quickTasks() async {
    final List<Project> projects =
        ref.read(projectsProvider).asData?.value ?? const <Project>[];
    final ({String prompt, int? projectId})? r = await showCreateTasksDialog(
      context,
      projects,
    );
    if (r == null) {
      return;
    }
    _add('user', 'Create tasks: ${r.prompt}');
    setState(() => _busy = true);
    try {
      final int count = await ref
          .read(aiRepositoryProvider)
          .createTasks(r.prompt, projectId: r.projectId);
      ref.invalidate(tasksProvider);
      _add('assistant', '✅ Created **$count** task${count == 1 ? '' : 's'}.');
    } catch (e) {
      _add('assistant', '⚠️ ${_friendly(e)}');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _meetingSummary() async {
    final String? input = await showAiInputDialog(
      context,
      title: 'Meeting notes → tasks + page',
      hint: 'Paste the meeting transcript or raw notes…',
    );
    if (input == null || input.trim().isEmpty) {
      return;
    }
    _add('user', 'Summarize the meeting and create tasks');
    setState(() => _busy = true);
    try {
      final AiMeetingResult res = await ref
          .read(aiRepositoryProvider)
          .meetingSummary(input);
      ref.invalidate(tasksProvider);
      final String suffix = res.taskCount > 0
          ? '\n\n✅ Created **${res.taskCount}** '
                'task${res.taskCount == 1 ? '' : 's'} and saved these notes as '
                'a page — find it in **Pages**.'
          : '\n\n📝 Saved these notes as a page — find it in **Pages**.';
      _add('assistant', '${res.summary}$suffix');
    } catch (e) {
      _add('assistant', '⚠️ ${_friendly(e)}');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _quickAction({
    required String label,
    required Future<String> Function(String input) run,
    required String hint,
    bool multiline = true,
  }) async {
    final String? input = await showAiInputDialog(
      context,
      title: label,
      hint: hint,
      multiline: multiline,
    );
    if (input == null || input.trim().isEmpty) {
      return;
    }
    _add('user', '$label: $input');
    setState(() => _busy = true);
    try {
      _add('assistant', await run(input));
    } catch (e) {
      _add('assistant', '⚠️ ${_friendly(e)}');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AiStatus> status = ref.watch(aiStatusProvider);
    final bool configured = status.asData?.value.configured ?? true;
    final AiRepository repo = ref.read(aiRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'AI Assistant',
            subtitle: 'Ask, create, summarize and search with Claude',
            actions: <Widget>[
              if (_turns.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(_turns.clear),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('New chat'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!configured) const _NotConfiguredBanner(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ActionChip(
                avatar: const Icon(Icons.add_task, size: 18),
                label: const Text('Create tasks'),
                onPressed: _busy ? null : _quickTasks,
              ),
              ActionChip(
                avatar: const Icon(Icons.summarize_outlined, size: 18),
                label: const Text('Summarize workspace'),
                onPressed: _busy
                    ? null
                    : () async {
                        _add('user', 'Summarize the workspace');
                        setState(() => _busy = true);
                        try {
                          _add('assistant', await repo.summarizeProject(null));
                        } catch (e) {
                          _add('assistant', '⚠️ ${_friendly(e)}');
                        } finally {
                          if (mounted) {
                            setState(() => _busy = false);
                          }
                        }
                      },
              ),
              ActionChip(
                avatar: const Icon(Icons.event_note_outlined, size: 18),
                label: const Text('Meeting notes'),
                onPressed: _busy
                    ? null
                    : () => _quickAction(
                        label: 'Meeting notes',
                        hint: 'Paste your raw meeting notes…',
                        run: repo.meetingNotes,
                      ),
              ),
              ActionChip(
                avatar: const Icon(Icons.summarize_outlined, size: 18),
                label: const Text('Notes → tasks + page'),
                onPressed: _busy ? null : _meetingSummary,
              ),
              ActionChip(
                avatar: const Icon(Icons.auto_fix_high_outlined, size: 18),
                label: const Text('Improve writing'),
                onPressed: _busy ? null : _quickWrite,
              ),
              ActionChip(
                avatar: const Icon(Icons.travel_explore_outlined, size: 18),
                label: const Text('Ask about my work'),
                onPressed: _busy
                    ? null
                    : () => _quickAction(
                        label: 'Search',
                        hint: 'e.g. what high-priority work is overdue?',
                        multiline: false,
                        run: repo.search,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _turns.isEmpty
                ? _Empty(busy: _busy)
                : ListView.builder(
                    controller: _scroll,
                    itemCount: _turns.length,
                    itemBuilder: (BuildContext context, int i) =>
                        _Bubble(turn: _turns[i]),
                  ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Ask the assistant anything…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _busy ? null : _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _quickWrite() async {
    final ({String action, String text})? r = await showWriteDialog(context);
    if (r == null) {
      return;
    }
    _add('user', '${_writeLabel(r.action)}:\n${r.text}');
    setState(() => _busy = true);
    try {
      _add(
        'assistant',
        await ref.read(aiRepositoryProvider).write(r.action, r.text),
      );
    } catch (e) {
      _add('assistant', '⚠️ ${_friendly(e)}');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _writeLabel(String a) => switch (a) {
    'improve' => 'Improve',
    'shorten' => 'Shorten',
    'expand' => 'Expand',
    'fix' => 'Fix grammar',
    'professional' => 'Make professional',
    'summarize' => 'Summarize',
    _ => 'Rewrite',
  };
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.turn});

  final _Turn turn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isUser = turn.role == 'user';
    final String name =
        ref.watch(authControllerProvider).asData?.value.user?.name ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isUser)
            UserAvatar(name: name, radius: 16)
          else
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.brand.withValues(alpha: 0.15),
              child: const Icon(
                Icons.auto_awesome,
                size: 18,
                color: AppColors.brand,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
                    : AppColors.brand.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isUser ? Text(turn.text) : MarkdownView(data: turn.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.busy});
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.auto_awesome, size: 48, color: AppColors.brand),
          const SizedBox(height: 12),
          Text(
            busy ? 'Thinking…' : 'Ask a question or pick a quick action above.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NotConfiguredBanner extends StatelessWidget {
  const _NotConfiguredBanner();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI is not configured yet. Set ANTHROPIC_API_KEY on the backend '
              '(and AI_MODEL to choose a Claude model) to enable the assistant.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
