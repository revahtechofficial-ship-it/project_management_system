import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import 'api_exception.dart';

/// Shared user-feedback helpers — one place for typed snackbars, clipboard
/// feedback and confirmation dialogs so every page gives consistent feedback
/// (AGENTS.md §1 `core/utils`).

enum _SnackKind { success, error, info, warning }

/// Concise, color-coded snackbars. Use from any widget: `context.showSuccess(…)`.
extension FeedbackMessages on BuildContext {
  void showSuccess(String message) =>
      _showSnack(this, message, _SnackKind.success);

  /// Takes anything you might have caught, not just a String — a `DioException`
  /// carries the server's own explanation, and [describeError] digs it out.
  /// `showError('Could not save: $e')` printed Dio's whole diagnostic instead;
  /// `showError(e)` prints the sentence the server actually wrote.
  void showError(Object? error) =>
      _showSnack(this, describeError(error), _SnackKind.error);

  void showInfo(String message) => _showSnack(this, message, _SnackKind.info);

  void showWarning(String message) =>
      _showSnack(this, message, _SnackKind.warning);

  /// Copies [text] to the clipboard and confirms with a toast.
  Future<void> copyToClipboard(String text, {String label = 'Copied'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showInfo(label);
    }
  }
}

void _showSnack(BuildContext context, String message, _SnackKind kind) {
  final (Color background, IconData icon) = switch (kind) {
    _SnackKind.success => (AppColors.green, Icons.check_circle_rounded),
    _SnackKind.error => (AppColors.rose, Icons.error_rounded),
    _SnackKind.info => (AppColors.slate, Icons.info_rounded),
    _SnackKind.warning => (AppColors.amber, Icons.warning_amber_rounded),
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
