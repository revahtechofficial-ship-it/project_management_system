import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Shared user-feedback helpers — one place for success/error/info snackbars
/// and confirmation dialogs so every page gives consistent feedback
/// (AGENTS.md §1 `core/utils`).

enum _SnackKind { success, error, info }

/// Concise, color-coded snackbars. Use from any widget: `context.showSuccess(…)`.
extension FeedbackMessages on BuildContext {
  void showSuccess(String message) =>
      _showSnack(this, message, _SnackKind.success);

  void showError(String message) => _showSnack(this, message, _SnackKind.error);

  void showInfo(String message) => _showSnack(this, message, _SnackKind.info);
}

void _showSnack(BuildContext context, String message, _SnackKind kind) {
  final (Color background, IconData icon) = switch (kind) {
    _SnackKind.success => (AppColors.green, Icons.check_circle_rounded),
    _SnackKind.error => (AppColors.rose, Icons.error_rounded),
    _SnackKind.info => (AppColors.slate, Icons.info_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: background,
        content: Row(
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
}

/// A standard confirm/cancel dialog. Returns true only when confirmed. Set
/// [destructive] to tint the confirm button with the error color.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: scheme.error)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// A destructive confirmation, e.g. `confirmDelete(context, what: 'this project')`.
Future<bool> confirmDelete(
  BuildContext context, {
  required String what,
  String? message,
}) {
  return showConfirmDialog(
    context,
    title: 'Delete $what?',
    message: message ?? "This action can't be undone.",
    confirmLabel: 'Delete',
    destructive: true,
  );
}
