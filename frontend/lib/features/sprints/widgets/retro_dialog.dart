import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../core/widgets/async_states.dart';
import '../../../data/enums/retro_kind.dart';
import '../../../data/models/retro_item.dart';
import '../providers/retro_providers.dart';

/// Opens the retrospective board for a sprint.
Future<void> showSprintRetroDialog(
  BuildContext context,
  int sprintId,
  String sprintName,
) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext _) =>
        _RetroDialog(sprintId: sprintId, sprintName: sprintName),
  );
}

class _RetroDialog extends ConsumerWidget {
  const _RetroDialog({required this.sprintId, required this.sprintName});
  final int sprintId;
  final String sprintName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RetroItem>> async =
        ref.watch(sprintRetroProvider(sprintId));
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Header(sprintName: sprintName),
            const Divider(height: 1),
            Flexible(
              child: async.when(
                loading: () => const SizedBox(
                    height: 200, child: LoadingView()),
                error: (Object e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorNotice(error: e),
                ),
                data: (List<RetroItem> items) {
                  List<RetroItem> of(RetroKind k) =>
                      items.where((RetroItem i) => i.kind == k).toList();
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints c) {
                            final List<Widget> columns = <Widget>[
                              _Column(
                                sprintId: sprintId,
                                kind: RetroKind.start,
                                items: of(RetroKind.start),
                              ),
                              _Column(
                                sprintId: sprintId,
                                kind: RetroKind.stop,
                                items: of(RetroKind.stop),
                              ),
                              _Column(
                                sprintId: sprintId,
                                kind: RetroKind.keepGoing,
                                items: of(RetroKind.keepGoing),
                              ),
                            ];
                            if (c.maxWidth < 720) {
                              return Column(
                                children: <Widget>[
                                  for (final Widget col in columns)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: col,
                                    ),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(child: columns[0]),
                                const SizedBox(width: 14),
                                Expanded(child: columns[1]),
                                const SizedBox(width: 14),
                                Expanded(child: columns[2]),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        _ActionSection(
                          sprintId: sprintId,
                          items: of(RetroKind.action),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sprintName});
  final String sprintName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.replay_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Retrospective · $sprintName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.sprintId,
    required this.kind,
    required this.items,
  });
  final int sprintId;
  final RetroKind kind;
  final List<RetroItem> items;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(kind.icon, size: 16, color: kind.color),
              const SizedBox(width: 6),
              Text(kind.label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Text('${items.length}',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          for (final RetroItem i in items) _RetroCard(item: i),
          _AddRetro(sprintId: sprintId, kind: kind),
        ],
      ),
    );
  }
}

class _RetroCard extends ConsumerWidget {
  const _RetroCard({required this.item});
  final RetroItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: Text(item.body)),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await ref.read(retroRepositoryProvider).delete(item.id);
                ref.invalidate(sprintRetroProvider(item.sprintId));
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close,
                    size: 15, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({required this.sprintId, required this.items});
  final int sprintId;
  final List<RetroItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RetroKind.action.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: RetroKind.action.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(RetroKind.action.icon, size: 16,
                  color: RetroKind.action.color),
              const SizedBox(width: 6),
              const Text('Action items',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          for (final RetroItem i in items) _ActionRow(item: i),
          _AddRetro(sprintId: sprintId, kind: RetroKind.action),
        ],
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.item});
  final RetroItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: item.done,
            onChanged: (bool? v) async {
              await ref
                  .read(retroRepositoryProvider)
                  .setDone(item.id, v ?? false);
              ref.invalidate(sprintRetroProvider(item.sprintId));
            },
          ),
        ),
        Expanded(
          child: Text(
            item.body,
            style: TextStyle(
              decoration: item.done ? TextDecoration.lineThrough : null,
              color: item.done ? scheme.onSurfaceVariant : null,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Delete',
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
          onPressed: () async {
            await ref.read(retroRepositoryProvider).delete(item.id);
            ref.invalidate(sprintRetroProvider(item.sprintId));
          },
        ),
      ],
    );
  }
}

class _AddRetro extends ConsumerStatefulWidget {
  const _AddRetro({required this.sprintId, required this.kind});
  final int sprintId;
  final RetroKind kind;

  @override
  ConsumerState<_AddRetro> createState() => _AddRetroState();
}

class _AddRetroState extends ConsumerState<_AddRetro> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final String body = _controller.text.trim();
    if (body.isEmpty || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(retroRepositoryProvider)
          .add(widget.sprintId, widget.kind, body);
      _controller.clear();
      ref.invalidate(sprintRetroProvider(widget.sprintId));
    } catch (e) {
      if (mounted) {
        context.showError('Could not add: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Add to ${widget.kind.label.toLowerCase()}',
              ),
              onSubmitted: (_) => _add(),
            ),
          ),
          IconButton(
            tooltip: 'Add',
            icon: const Icon(Icons.add, size: 20),
            onPressed: _busy ? null : _add,
          ),
        ],
      ),
    );
  }
}
