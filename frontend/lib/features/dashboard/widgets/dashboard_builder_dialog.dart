import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/enums/dashboard_widget.dart';
import '../../../data/models/saved_dashboard.dart';
import '../providers/dashboards_providers.dart';

/// Opens the create/edit dialog for a dashboard. Returns the saved dashboard,
/// or null if cancelled.
Future<SavedDashboard?> showDashboardBuilder(
  BuildContext context, {
  SavedDashboard? existing,
}) {
  return showDialog<SavedDashboard>(
    context: context,
    builder: (BuildContext context) => _DashboardBuilder(existing: existing),
  );
}

class _DashboardBuilder extends ConsumerStatefulWidget {
  const _DashboardBuilder({this.existing});

  final SavedDashboard? existing;

  @override
  ConsumerState<_DashboardBuilder> createState() => _DashboardBuilderState();
}

class _DashboardBuilderState extends ConsumerState<_DashboardBuilder> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late String _visibility = widget.existing?.visibility ?? 'workspace';
  late final Set<String> _selected = <String>{...?widget.existing?.widgets};
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'A name is required');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = 'Pick at least one widget');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    // Persist in the catalogue's order for a stable layout.
    final List<String> widgets = <String>[
      for (final DashboardWidgetKind k in DashboardWidgetKind.values)
        if (_selected.contains(k.key)) k.key,
    ];
    try {
      final repo = ref.read(dashboardsRepositoryProvider);
      final SavedDashboard result;
      if (_isEdit) {
        await repo.update(
          widget.existing!.id,
          name: name,
          visibility: _visibility,
          widgets: widgets,
        );
        result = await repo.get(widget.existing!.id);
      } else {
        result = await repo.create(
          name: name,
          visibility: _visibility,
          widgets: widgets,
        );
      }
      ref.invalidate(savedDashboardsProvider);
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_isEdit ? 'Edit dashboard' : 'New dashboard'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'workspace',
                  icon: Icon(Icons.groups_outlined, size: 18),
                  label: Text('Everyone'),
                ),
                ButtonSegment<String>(
                  value: 'private',
                  icon: Icon(Icons.lock_outline, size: 18),
                  label: Text('Private'),
                ),
              ],
              selected: <String>{_visibility},
              showSelectedIcon: false,
              onSelectionChanged: (Set<String> s) =>
                  setState(() => _visibility = s.first),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Widgets',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final DashboardWidgetKind k
                        in DashboardWidgetKind.values)
                      FilterChip(
                        avatar: Icon(k.icon, size: 18, color: k.color),
                        label: Text(k.label),
                        selected: _selected.contains(k.key),
                        onSelected: (bool on) => setState(() {
                          if (on) {
                            _selected.add(k.key);
                          } else {
                            _selected.remove(k.key);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
