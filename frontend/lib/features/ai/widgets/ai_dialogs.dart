import 'package:flutter/material.dart';

import '../../../data/models/project.dart';

/// A simple single-field prompt dialog. Returns the entered text, or null.
Future<String?> showAiInputDialog(
  BuildContext context, {
  required String title,
  required String hint,
  bool multiline = true,
}) {
  final TextEditingController controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: multiline ? 4 : 1,
          maxLines: multiline ? 10 : 1,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Run'),
        ),
      ],
    ),
  );
}

/// Asks for a prompt and an optional project to create tasks in.
Future<({String prompt, int? projectId})?> showCreateTasksDialog(
  BuildContext context,
  List<Project> projects,
) {
  final TextEditingController controller = TextEditingController();
  int? projectId;
  return showDialog<({String prompt, int? projectId})>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, void Function(void Function()) setState) {
        return AlertDialog(
          title: const Text('Create tasks with AI'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText:
                        'Describe the work, e.g. "Plan the Q3 marketing launch"',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: projectId,
                  decoration: const InputDecoration(
                    labelText: 'Project (optional)',
                  ),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(child: Text('No project')),
                    for (final Project p in projects)
                      DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (int? v) => setState(() => projectId = v),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  (prompt: controller.text.trim(), projectId: projectId),
                );
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    ),
  );
}

const List<(String, String)> _writeActions = <(String, String)>[
  ('improve', 'Improve'),
  ('fix', 'Fix grammar'),
  ('shorten', 'Shorten'),
  ('expand', 'Expand'),
  ('professional', 'Make professional'),
  ('summarize', 'Summarize'),
];

/// Asks for text and a rewrite action.
Future<({String action, String text})?> showWriteDialog(BuildContext context) {
  final TextEditingController controller = TextEditingController();
  String action = 'improve';
  return showDialog<({String action, String text})>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, void Function(void Function()) setState) {
        return AlertDialog(
          title: const Text('Writing assistant'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: action,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: <DropdownMenuItem<String>>[
                    for (final (String key, String label) in _writeActions)
                      DropdownMenuItem<String>(value: key, child: Text(label)),
                  ],
                  onChanged: (String? v) =>
                      setState(() => action = v ?? 'improve'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'Paste the text to rewrite…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  (action: action, text: controller.text.trim()),
                );
              },
              child: const Text('Rewrite'),
            ),
          ],
        );
      },
    ),
  );
}
