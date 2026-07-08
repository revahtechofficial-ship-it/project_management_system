import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/feedback.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/dashboard_card.dart';
import '../../core/widgets/markdown_view.dart';
import '../../core/widgets/page_header.dart';
import '../../data/repositories/ai_repository.dart';
import '../ai/providers/ai_providers.dart';

/// Weekly recap: an AI-written "what happened this week" summary of workspace
/// activity, generated on demand.
class RecapPage extends ConsumerStatefulWidget {
  const RecapPage({super.key});

  @override
  ConsumerState<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends ConsumerState<RecapPage> {
  int _days = 7;
  bool _loading = false;
  AiRecapResult? _result;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final AiRecapResult r =
          await ref.read(aiRepositoryProvider).recap(days: _days);
      if (mounted) {
        setState(() {
          _result = r;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not generate the recap. $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool configured =
        ref.watch(aiStatusProvider).asData?.value.configured ?? true;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            title: 'Weekly recap',
            subtitle: 'An AI summary of what happened',
            actions: <Widget>[
              SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 7, label: Text('7 days')),
                  ButtonSegment<int>(value: 14, label: Text('14 days')),
                  ButtonSegment<int>(value: 30, label: Text('30 days')),
                ],
                selected: <int>{_days},
                showSelectedIcon: false,
                onSelectionChanged: (Set<int> s) =>
                    setState(() => _days = s.first),
              ),
              FilledButton.icon(
                onPressed: _loading || !configured ? null : _generate,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(_result == null ? 'Generate' : 'Regenerate'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!configured)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline, size: 18,
                      color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI is not configured. Set ANTHROPIC_API_KEY on the '
                      'backend to enable the weekly recap.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _content(context, scheme)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, ColorScheme scheme) {
    if (_loading) {
      return const LoadingView();
    }
    if (_error != null) {
      return ErrorView(error: _error!, onRetry: _generate);
    }
    final AiRecapResult? r = _result;
    if (r == null) {
      return const EmptyState(
        icon: Icons.auto_awesome,
        title: 'Generate a recap',
        message: 'Summarise the last few days of activity — completed work, '
            'new work and notable changes — into a shareable recap.',
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _Stat(
                label: '${r.activityCount} updates',
                icon: Icons.history,
              ),
              _Stat(
                label: '${r.contributors} '
                    '${r.contributors == 1 ? 'contributor' : 'contributors'}',
                icon: Icons.groups_outlined,
              ),
              _Stat(label: 'last ${r.days} days', icon: Icons.event_outlined),
            ],
          ),
          const SizedBox(height: 14),
          DashboardCard(
            child: r.recap.trim().isEmpty
                ? Text('The recap came back empty. Try again.',
                    style: TextStyle(color: scheme.onSurfaceVariant))
                : MarkdownView(data: r.recap),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: r.recap));
                if (context.mounted) {
                  context.showSuccess('Recap copied');
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
