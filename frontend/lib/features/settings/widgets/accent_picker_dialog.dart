import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_providers.dart';

/// A spectrum of swatches for the custom accent picker.
const List<Color> _palette = <Color>[
  Color(0xFF4F46E5),
  Color(0xFF6366F1),
  Color(0xFF2563EB),
  Color(0xFF0284C7),
  Color(0xFF0891B2),
  Color(0xFF0D9488),
  Color(0xFF059669),
  Color(0xFF16A34A),
  Color(0xFF65A30D),
  Color(0xFFCA8A04),
  Color(0xFFD97706),
  Color(0xFFEA580C),
  Color(0xFFDC2626),
  Color(0xFFE11D48),
  Color(0xFFDB2777),
  Color(0xFFC026D3),
  Color(0xFF9333EA),
  Color(0xFF7C3AED),
  Color(0xFF475569),
  Color(0xFF57534E),
];

/// Opens the custom accent picker; applies the chosen color to settings.
Future<void> showAccentPicker(
  BuildContext context,
  WidgetRef ref,
  Color current,
) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => _AccentPickerDialog(
      current: current,
      onApply: (Color c) =>
          ref.read(settingsControllerProvider.notifier).setAccent(c.toARGB32()),
    ),
  );
}

class _AccentPickerDialog extends StatefulWidget {
  const _AccentPickerDialog({required this.current, required this.onApply});
  final Color current;
  final ValueChanged<Color> onApply;

  @override
  State<_AccentPickerDialog> createState() => _AccentPickerDialogState();
}

class _AccentPickerDialogState extends State<_AccentPickerDialog> {
  late Color _selected = widget.current;
  late final TextEditingController _hex = TextEditingController(
    text: _hexOf(widget.current),
  );

  static String _hexOf(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _applyHex(String value) {
    final String cleaned = value.replaceAll('#', '').trim();
    if (cleaned.length != 6) {
      return;
    }
    final int? rgb = int.tryParse(cleaned, radix: 16);
    if (rgb == null) {
      return;
    }
    setState(() => _selected = Color(0xFF000000 | rgb));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Custom accent'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final Color c in _palette)
                  _Swatch(
                    color: c,
                    selected: c.toARGB32() == _selected.toARGB32(),
                    onTap: () => setState(() {
                      _selected = c;
                      _hex.text = _hexOf(c);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selected,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    decoration: const InputDecoration(
                      labelText: 'Hex',
                      hintText: '#4F46E5',
                      isDense: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(7),
                    ],
                    onChanged: _applyHex,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onApply(_selected);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
