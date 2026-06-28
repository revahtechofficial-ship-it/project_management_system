import 'package:flutter/material.dart';

/// A thin top progress bar shown while a section refreshes (AGENTS.md §1
/// `core/widgets`).
class LoadingBar extends StatelessWidget {
  const LoadingBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 16),
      child: LinearProgressIndicator(minHeight: 2),
    );
  }
}

/// A centered spinner for a full-page first load. The single shared loading
/// view so every page loads the same way.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// A centered icon + message for an empty list/section.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: <Widget>[
            Icon(icon, size: 36, color: scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// An inline error banner for a failed load. Leads with a friendly message and
/// only shows the raw error as a muted secondary line; an optional [onRetry]
/// adds a Retry action.
class ErrorNotice extends StatelessWidget {
  const ErrorNotice({super.key, this.error, this.message, this.onRetry});

  final Object? error;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  message ?? "Couldn't load this. Please try again.",
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '$error',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onErrorContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onErrorContainer,
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A centered, width-constrained [ErrorNotice] for a full-page failed load.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.error, this.message, this.onRetry});

  final Object? error;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorNotice(error: error, message: message, onRetry: onRetry),
        ),
      ),
    );
  }
}
