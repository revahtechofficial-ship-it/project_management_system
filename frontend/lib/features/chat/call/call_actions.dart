import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/feedback.dart';
import '../../../data/models/call_credentials.dart';
import '../providers/chat_providers.dart';
import 'call_screen.dart';

/// Starts a call in [conversationId], ringing the other members, and opens the
/// call screen for the caller.
Future<void> startCall(
  BuildContext context,
  WidgetRef ref,
  int conversationId,
  String mode, {
  String title = '',
}) async {
  try {
    final CallCredentials creds = await ref
        .read(chatRepositoryProvider)
        .requestCall(conversationId, mode: mode, ring: true);
    if (!context.mounted) {
      return;
    }
    await _openCall(context, creds, title);
  } catch (e) {
    if (context.mounted) {
      context.showError('Call failed: $e');
    }
  }
}

/// Shows an incoming-call prompt; on accept, joins the call (without ringing).
Future<void> showIncomingCall(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> event,
) async {
  final int conversationId = event['conversation_id'] as int;
  final String fromName = event['from_name'] as String? ?? 'Someone';
  final String mode = event['mode'] as String? ?? 'video';

  final bool join =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          icon: Icon(mode == 'video' ? Icons.videocam : Icons.call, size: 36),
          title: Text('Incoming ${mode == 'video' ? 'video ' : ''}call'),
          content: Text('$fromName is calling…'),
          actions: <Widget>[
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.call_end, color: Colors.red),
              label: const Text('Decline'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.call),
              label: const Text('Join'),
            ),
          ],
        ),
      ) ??
      false;
  if (!join || !context.mounted) {
    return;
  }
  try {
    final CallCredentials creds = await ref
        .read(chatRepositoryProvider)
        .requestCall(conversationId, mode: mode, ring: false);
    if (!context.mounted) {
      return;
    }
    await _openCall(context, creds, fromName);
  } catch (e) {
    if (context.mounted) {
      context.showError('Could not join: $e');
    }
  }
}

Future<void> _openCall(
  BuildContext context,
  CallCredentials creds,
  String title,
) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext _) => CallScreen(
        url: creds.url,
        token: creds.token,
        mode: creds.mode,
        title: title,
      ),
    ),
  );
}
