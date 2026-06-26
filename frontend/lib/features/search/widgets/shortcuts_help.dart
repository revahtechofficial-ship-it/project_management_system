import 'package:flutter/material.dart';

/// Opens the keyboard-shortcuts cheat sheet.
Future<void> showShortcutsHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (BuildContext context) => const _ShortcutsHelp(),
);

const List<(String, String)> _shortcuts = <(String, String)>[
  ('Ctrl / ⌘ + K', 'Open the command bar'),
  ('?', 'Show this shortcuts list'),
  ('Enter', 'Open the first result'),
  ('Esc', 'Close the command bar'),
];

class _ShortcutsHelp extends StatelessWidget {
  const _ShortcutsHelp();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (String keys, String desc) in _shortcuts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(desc)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        keys,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
