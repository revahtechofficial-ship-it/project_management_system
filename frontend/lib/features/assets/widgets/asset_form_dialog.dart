import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/feedback.dart';
import '../../../data/enums/asset_kind.dart';
import '../../../data/enums/asset_status.dart';
import '../../../data/models/asset.dart';
import '../../../data/models/team_member.dart';
import '../../../data/repositories/assets_repository.dart';
import '../../team/providers/team_providers.dart';
import '../providers/assets_providers.dart';

/// Opens the create/edit dialog for an inventory [Asset]. Pass [existing] to
/// edit; omit it to add a new item. Returns true when something was saved.
Future<bool?> showAssetFormDialog(BuildContext context, {Asset? existing}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext _) => _AssetFormDialog(existing: existing),
  );
}

class _AssetFormDialog extends ConsumerStatefulWidget {
  const _AssetFormDialog({this.existing});
  final Asset? existing;

  @override
  ConsumerState<_AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends ConsumerState<_AssetFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _identifier;
  late final TextEditingController _vendor;
  late final TextEditingController _cost;
  late final TextEditingController _notes;
  late AssetKind _kind;
  late AssetStatus _status;
  int? _assigneeId;
  DateTime? _purchasedOn;
  DateTime? _expiresOn;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final Asset? a = widget.existing;
    _name = TextEditingController(text: a?.name ?? '');
    _identifier = TextEditingController(text: a?.identifier ?? '');
    _vendor = TextEditingController(text: a?.vendor ?? '');
    _cost = TextEditingController(
      text: a == null || a.costCents == 0 ? '' : a.cost.toStringAsFixed(2),
    );
    _notes = TextEditingController(text: a?.notes ?? '');
    _kind = a?.kind ?? AssetKind.hardware;
    _status = a?.status ?? AssetStatus.available;
    _assigneeId = a?.assigneeId;
    _purchasedOn = a?.purchasedOn;
    _expiresOn = a?.expiresOn;
  }

  @override
  void dispose() {
    _name.dispose();
    _identifier.dispose();
    _vendor.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  int _costCents() {
    final double v = double.tryParse(_cost.text.trim()) ?? 0;
    return (v * 100).round();
  }

  Future<void> _pickDate(bool purchase) async {
    final DateTime now = DateTime.now();
    final DateTime initial =
        (purchase ? _purchasedOn : _expiresOn) ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      setState(() {
        if (purchase) {
          _purchasedOn = picked;
        } else {
          _expiresOn = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _busy) {
      return;
    }
    setState(() => _busy = true);
    final Asset payload = Asset(
      id: widget.existing?.id ?? 0,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      name: _name.text.trim(),
      kind: _kind,
      status: _status,
      identifier: _identifier.text.trim(),
      vendor: _vendor.text.trim(),
      assigneeId: _assigneeId,
      costCents: _costCents(),
      purchasedOn: _purchasedOn,
      expiresOn: _expiresOn,
      notes: _notes.text.trim(),
    );
    try {
      final AssetsRepository repo = ref.read(assetsRepositoryProvider);
      if (widget.existing == null) {
        await repo.create(payload);
      } else {
        await repo.update(widget.existing!.id, payload);
      }
      ref.invalidate(assetsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        context.showError('Could not save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<TeamMember> members =
        ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    final bool editing = widget.existing != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: <Widget>[
                  Icon(_kind.icon, color: _kind.color),
                  const SizedBox(width: 10),
                  Text(
                    editing ? 'Edit asset' : 'New asset',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: _name,
                      autofocus: !editing,
                      decoration: const InputDecoration(
                          labelText: 'Name', isDense: true),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<AssetKind>(
                            initialValue: _kind,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Type', isDense: true),
                            items: <DropdownMenuItem<AssetKind>>[
                              for (final AssetKind k in AssetKind.values)
                                DropdownMenuItem<AssetKind>(
                                  value: k,
                                  child: Text(k.label),
                                ),
                            ],
                            onChanged: (AssetKind? v) =>
                                setState(() => _kind = v ?? _kind),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<AssetStatus>(
                            initialValue: _status,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Status', isDense: true),
                            items: <DropdownMenuItem<AssetStatus>>[
                              for (final AssetStatus s in AssetStatus.values)
                                DropdownMenuItem<AssetStatus>(
                                  value: s,
                                  child: Text(s.label),
                                ),
                            ],
                            onChanged: (AssetStatus? v) =>
                                setState(() => _status = v ?? _status),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _identifier,
                      decoration: InputDecoration(
                          labelText: _kind.identifierLabel, isDense: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _vendor,
                      decoration: const InputDecoration(
                          labelText: 'Vendor', isDense: true),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _assigneeId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Assigned to', isDense: true),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          child: Text('Unassigned'),
                        ),
                        for (final TeamMember m in members)
                          DropdownMenuItem<int?>(
                            value: m.id,
                            child: Text(m.name.isEmpty ? m.email : m.name,
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (int? v) => setState(() => _assigneeId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cost,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Cost',
                        isDense: true,
                        prefixText: '\$ ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      label: 'Purchased',
                      value: _purchasedOn,
                      onPick: () => _pickDate(true),
                      onClear: () => setState(() => _purchasedOn = null),
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      label: 'Expires / warranty ends',
                      value: _expiresOn,
                      onPick: () => _pickDate(false),
                      onClear: () => setState(() => _expiresOn = null),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: 'Notes', isDense: true),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(editing ? 'Save' : 'Add'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only field that shows a chosen date and opens a picker on tap.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final DateTime? v = value;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixIcon: const Icon(Icons.event_outlined, size: 18),
          suffixIcon: v == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClear,
                ),
        ),
        child: Text(v == null ? '—' : '${shortDate(v)} ${v.year}'),
      ),
    );
  }
}
