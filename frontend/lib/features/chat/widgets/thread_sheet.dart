import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/mentions.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/team_member.dart';
import '../../../providers/auth_provider.dart';
import '../../team/providers/team_providers.dart';
import '../providers/chat_providers.dart';

/// Opens the thread for [root] — its replies plus a composer to add more.
/// Resolves to the thread's reply count when closed via the header (so the
/// caller can refresh the parent's "N replies" badge), or null if dismissed.
Future<int?> showThreadSheet(BuildContext context, ChatMessage root) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => _ThreadSheet(root: root),
  );
}

class _ThreadSheet extends ConsumerStatefulWidget {
  const _ThreadSheet({required this.root});

  final ChatMessage root;

  @override
  ConsumerState<_ThreadSheet> createState() => _ThreadSheetState();
}

class _ThreadSheetState extends ConsumerState<_ThreadSheet> {
  final TextEditingController _input = TextEditingController();
  List<ChatMessage> _replies = <ChatMessage>[];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<ChatMessage> r = await ref
          .read(chatRepositoryProvider)
          .threadReplies(widget.root.id);
      if (mounted) {
        setState(() {
          _replies = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _send() async {
    final String body = _input.text.trim();
    if (body.isEmpty) {
      return;
    }
    setState(() => _sending = true);
    final List<TeamMember> team =
        ref.read(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    try {
      final ChatMessage msg = await ref
          .read(chatRepositoryProvider)
          .sendText(
            widget.root.conversationId,
            body,
            replyTo: widget.root.id,
            mentions: parseMentions(body, mentionTokenMap(team)),
          );
      _input.clear();
      setState(() {
        _replies = <ChatMessage>[..._replies, msg];
        _sending = false;
      });
      ref.invalidate(conversationsProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int? myId = ref.watch(authControllerProvider).asData?.value.user?.id;
    final double maxH = MediaQuery.of(context).size.height * 0.85;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: maxH,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.forum_outlined, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Thread',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, _replies.length),
                  ),
                ],
              ),
            ),
            _RootMessage(message: widget.root),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _replies.isEmpty
                  ? Center(
                      child: Text(
                        'No replies yet. Start the thread.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _replies.length,
                      itemBuilder: (BuildContext context, int i) => _ReplyTile(
                        message: _replies[i],
                        mine: _replies[i].senderId == myId,
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Reply in thread…',
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RootMessage extends StatelessWidget {
  const _RootMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UserAvatar(
            name: message.senderName ?? 'You',
            radius: 16,
            imageUrl: message.senderAvatarUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message.senderName ?? 'You',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  message.body.isEmpty
                      ? ChatMessage.previewFor(message.kind, message.body)
                      : message.body,
                  style: TextStyle(color: scheme.onSurface),
                ),
              ],
            ),
          ),
          Text(
            relativeTime(message.createdAt),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UserAvatar(
            name: message.senderName ?? 'You',
            radius: 14,
            imageUrl: message.senderAvatarUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      mine ? 'You' : (message.senderName ?? 'Member'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      relativeTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message.hasAttachment
                      ? ChatMessage.previewFor(message.kind, message.body)
                      : message.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
