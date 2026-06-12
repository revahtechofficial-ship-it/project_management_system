import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_reaction.dart';
import '../../data/models/conversation.dart';
import '../../data/repositories/chat_repository.dart';
import '../../providers/auth_provider.dart';
import 'call/call_actions.dart';
import 'providers/chat_providers.dart';
import 'widgets/new_conversation_dialog.dart';

/// Emojis offered in the quick-reaction row of the message action sheet.
const List<String> _quickReactions = <String>[
  '👍', '❤️', '😂', '😮', '😢', '🙏', '🎉', '🔥'
];

/// The messaging feature: a conversation list beside a live message thread
/// (AGENTS.md §1 feature page). Real-time updates arrive over the chat socket.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  static const int _pageSize = 30;

  int? _selectedId;
  List<ChatMessage> _messages = <ChatMessage>[];
  Map<int, Map<String, Set<int>>> _reactions = <int, Map<String, Set<int>>>{};
  int? _editingId;
  bool _loadingMessages = false;
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;
  bool _sending = false;
  bool _emojiOpen = false;
  String? _typingName;
  Timer? _typingClear;
  DateTime? _lastTypingSent;
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  int? get _myId => ref.read(authControllerProvider).asData?.value.user?.id;
  String? get _token =>
      ref.read(authControllerProvider).asData?.value.token;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _typingClear?.cancel();
    _scroll.removeListener(_onScroll);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels <= 80) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMoreOlder || _selectedId == null) {
      return;
    }
    _loadingOlder = true;
    try {
      final List<ChatMessage> older = await _repo.messages(_selectedId!,
          limit: _pageSize, offset: _messages.length);
      if (!mounted) {
        return;
      }
      final double prevExtent =
          _scroll.hasClients ? _scroll.position.maxScrollExtent : 0;
      final double prevPixels = _scroll.hasClients ? _scroll.position.pixels : 0;
      setState(() {
        _messages = <ChatMessage>[...older.reversed, ..._messages];
        _hasMoreOlder = older.length == _pageSize;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(
              prevPixels + (_scroll.position.maxScrollExtent - prevExtent));
        }
      });
    } finally {
      _loadingOlder = false;
    }
  }

  Map<int, Map<String, Set<int>>> _buildReactions(List<ChatReaction> hits) {
    final Map<int, Map<String, Set<int>>> map = <int, Map<String, Set<int>>>{};
    for (final ChatReaction r in hits) {
      map
          .putIfAbsent(r.messageId, () => <String, Set<int>>{})
          .putIfAbsent(r.emoji, () => <int>{})
          .add(r.userId);
    }
    return map;
  }

  Future<void> _toggleReaction(int messageId, String emoji) async {
    final int? me = _myId;
    if (me != null) {
      setState(() {
        final Map<String, Set<int>> forMsg =
            _reactions.putIfAbsent(messageId, () => <String, Set<int>>{});
        final Set<int> users = forMsg.putIfAbsent(emoji, () => <int>{});
        if (!users.remove(me)) {
          users.add(me);
        }
        if (users.isEmpty) {
          forMsg.remove(emoji);
        }
      });
    }
    try {
      await _repo.toggleReaction(messageId, emoji);
    } catch (e) {
      _err('Reaction failed: $e');
    }
  }

  void _applyReactionEvent(Map<String, dynamic> e) {
    final int messageId = e['message_id'] as int;
    final String emoji = e['emoji'] as String;
    final int userId = e['user_id'] as int;
    final bool added = e['added'] as bool? ?? false;
    setState(() {
      final Map<String, Set<int>> forMsg =
          _reactions.putIfAbsent(messageId, () => <String, Set<int>>{});
      final Set<int> users = forMsg.putIfAbsent(emoji, () => <int>{});
      if (added) {
        users.add(userId);
      } else {
        users.remove(userId);
        if (users.isEmpty) {
          forMsg.remove(emoji);
        }
      }
    });
  }

  void _onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'message':
        final ChatMessage msg =
            ChatMessage.fromJson(e['message'] as Map<String, dynamic>);
        ref.invalidate(conversationsProvider);
        if (msg.conversationId == _selectedId) {
          if (!_messages.any((ChatMessage m) => m.id == msg.id)) {
            setState(() {
              _messages = <ChatMessage>[..._messages, msg];
              _typingName = null;
            });
            _scrollToBottom();
          }
          _repo.markRead(msg.conversationId);
        }
      case 'typing':
        if (e['conversation_id'] == _selectedId && e['from_id'] != _myId) {
          setState(() => _typingName = e['from_name'] as String?);
          _typingClear?.cancel();
          _typingClear = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() => _typingName = null);
            }
          });
        }
      case 'message_deleted':
        if (e['conversation_id'] == _selectedId) {
          final int id = e['id'] as int;
          setState(() =>
              _messages = _messages.where((ChatMessage m) => m.id != id).toList());
        }
        ref.invalidate(conversationsProvider);
      case 'message_edited':
        if (e['conversation_id'] == _selectedId) {
          final ChatMessage edited =
              ChatMessage.fromJson(e['message'] as Map<String, dynamic>);
          setState(() => _messages = _messages
              .map((ChatMessage m) => m.id == edited.id ? edited : m)
              .toList());
        }
      case 'reaction':
        if (e['conversation_id'] == _selectedId) {
          _applyReactionEvent(e);
        }
    }
  }

  void _handleTyping() {
    if (_selectedId == null) {
      return;
    }
    final DateTime now = DateTime.now();
    if (_lastTypingSent != null &&
        now.difference(_lastTypingSent!).inMilliseconds < 2000) {
      return;
    }
    _lastTypingSent = now;
    final String name =
        ref.read(authControllerProvider).asData?.value.user?.name ?? '';
    ref.read(chatSocketProvider)?.send(<String, dynamic>{
      'type': 'typing',
      'conversation_id': _selectedId,
      'from_name': name,
    });
  }

  void _toggleEmoji() => setState(() => _emojiOpen = !_emojiOpen);

  void _insertEmoji(String emoji) {
    final String text = _composer.text;
    final TextSelection sel = _composer.selection;
    final int start = sel.start < 0 ? text.length : sel.start;
    final int end = sel.end < 0 ? text.length : sel.end;
    _composer.text = text.replaceRange(start, end, emoji);
    _composer.selection =
        TextSelection.collapsed(offset: start + emoji.length);
  }

  Future<void> _deleteMessage(int id) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Delete message'),
            content: const Text('Delete this message for everyone?'),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    try {
      await _repo.deleteMessage(id);
      setState(() =>
          _messages = _messages.where((ChatMessage m) => m.id != id).toList());
      ref.invalidate(conversationsProvider);
    } catch (e) {
      _err('Could not delete: $e');
    }
  }

  Future<void> _open(int id) async {
    setState(() {
      _selectedId = id;
      _messages = <ChatMessage>[];
      _reactions = <int, Map<String, Set<int>>>{};
      _editingId = null;
      _hasMoreOlder = true;
      _loadingMessages = true;
      _emojiOpen = false;
    });
    _composer.clear();
    try {
      final List<ChatMessage> msgs = await _repo.messages(id, limit: _pageSize);
      if (!mounted || _selectedId != id) {
        return;
      }
      setState(() {
        _messages = msgs.reversed.toList();
        _hasMoreOlder = msgs.length == _pageSize;
        _loadingMessages = false;
      });
      _scrollToBottom();
      await _repo.markRead(id);
      ref.invalidate(conversationsProvider);
      final List<ChatReaction> rx = await _repo.reactions(id);
      if (mounted && _selectedId == id) {
        setState(() => _reactions = _buildReactions(rx));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMessages = false);
      }
    }
  }

  Future<void> _sendText() async {
    final String body = _composer.text.trim();
    if (body.isEmpty || _selectedId == null) {
      return;
    }
    if (_editingId != null) {
      await _submitEdit(body);
      return;
    }
    _composer.clear();
    setState(() => _sending = true);
    try {
      _appendMine(await _repo.sendText(_selectedId!, body));
    } catch (e) {
      _err('Could not send: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _startEdit(ChatMessage m) {
    setState(() {
      _editingId = m.id;
      _emojiOpen = false;
    });
    _composer.text = m.body;
    _composer.selection =
        TextSelection.collapsed(offset: _composer.text.length);
  }

  void _cancelEdit() {
    setState(() => _editingId = null);
    _composer.clear();
  }

  Future<void> _submitEdit(String body) async {
    final int id = _editingId!;
    _composer.clear();
    setState(() => _editingId = null);
    try {
      final ChatMessage updated = await _repo.editMessage(id, body);
      setState(() => _messages = _messages
          .map((ChatMessage m) => m.id == id ? updated : m)
          .toList());
    } catch (e) {
      _err('Edit failed: $e');
    }
  }

  Future<void> _showMessageActions(ChatMessage m, bool isMine) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final String e in _quickReactions)
                    IconButton(
                      icon: Text(e, style: const TextStyle(fontSize: 24)),
                      onPressed: () {
                        Navigator.pop(sheet);
                        _toggleReaction(m.id, e);
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (m.body.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: m.body));
                  Navigator.pop(sheet);
                },
              ),
            if (isMine && m.kind == 'text')
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(sheet);
                  _startEdit(m);
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheet);
                  _deleteMessage(m.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendFile() async {
    if (_selectedId == null) {
      return;
    }
    final FilePickerResult? result =
        await FilePicker.pickFiles(withData: true);
    final bytes = result?.files.first.bytes;
    if (result == null || bytes == null) {
      return;
    }
    setState(() => _sending = true);
    try {
      _appendMine(await _repo.uploadFile(
          _selectedId!, bytes, result.files.first.name));
    } catch (e) {
      _err('Upload failed: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _appendMine(ChatMessage msg) {
    if (!_messages.any((ChatMessage m) => m.id == msg.id)) {
      setState(() => _messages = <ChatMessage>[..._messages, msg]);
    }
    _scrollToBottom();
    ref.invalidate(conversationsProvider);
  }

  void _err(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _back() => setState(() => _selectedId = null);

  Future<void> _startCall(String mode) async {
    if (_selectedId == null) {
      return;
    }
    final Conversation? conv = _selectedFrom(
        ref.read(conversationsProvider).asData?.value ??
            const <Conversation>[]);
    await startCall(context, ref, _selectedId!, mode,
        title: conv?.name ?? '');
  }

  Future<void> _newDm() async {
    final int? id = await startDirectMessage(context, ref);
    if (id != null) {
      ref.invalidate(conversationsProvider);
      await _open(id);
    }
  }

  Future<void> _newGroup() async {
    final int? id = await createGroupChat(context, ref);
    if (id != null) {
      ref.invalidate(conversationsProvider);
      await _open(id);
    }
  }

  Conversation? _selectedFrom(List<Conversation> list) {
    for (final Conversation c in list) {
      if (c.id == _selectedId) {
        return c;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Map<String, dynamic>>>(chatEventsProvider,
        (AsyncValue<Map<String, dynamic>>? prev,
            AsyncValue<Map<String, dynamic>> next) {
      next.whenData(_onEvent);
    });

    final List<Conversation> convos =
        ref.watch(conversationsProvider).asData?.value ??
            const <Conversation>[];
    final Set<int> online =
        ref.watch(presenceProvider).asData?.value ?? const <int>{};
    final Conversation? selected = _selectedFrom(convos);
    final bool wide = MediaQuery.sizeOf(context).width >= 820;

    if (wide) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
                width: 320,
                child: _ListPane(state: this, convos: convos, online: online)),
            const SizedBox(width: 12),
            Expanded(
                child: _ThreadPane(
                    state: this, conversation: selected, online: online)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _selectedId == null
          ? _ListPane(state: this, convos: convos, online: online)
          : _ThreadPane(
              state: this,
              conversation: selected,
              online: online,
              showBack: true),
    );
  }
}

/// The left pane: conversation list with a "new chat" menu.
class _ListPane extends StatelessWidget {
  const _ListPane(
      {required this.state, required this.convos, required this.online});
  final _ChatPageState state;
  final List<Conversation> convos;
  final Set<int> online;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: <Widget>[
                const Text('Chat',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'New conversation',
                  icon: const Icon(Icons.edit_square),
                  onSelected: (String v) =>
                      v == 'dm' ? state._newDm() : state._newGroup(),
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                        value: 'dm',
                        child: ListTile(
                            leading: Icon(Icons.person_add_alt_1),
                            title: Text('New message'))),
                    PopupMenuItem<String>(
                        value: 'group',
                        child: ListTile(
                            leading: Icon(Icons.group_add),
                            title: Text('New group'))),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: convos.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No conversations yet.\nStart a new chat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                  )
                : ListView.builder(
                    itemCount: convos.length,
                    itemBuilder: (BuildContext context, int i) =>
                        _ConversationTile(
                      conversation: convos[i],
                      selected: convos[i].id == state._selectedId,
                      online: !convos[i].isGroup &&
                          convos[i].otherUserId != null &&
                          online.contains(convos[i].otherUserId),
                      onTap: () => state._open(convos[i].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.online,
    required this.onTap,
  });
  final Conversation conversation;
  final bool selected;
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int unread = conversation.unreadCount;
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: _PresenceAvatar(
        online: online,
        child: conversation.isGroup
            ? CircleAvatar(
                backgroundColor: AppColors.brand.withValues(alpha: 0.15),
                child: const Icon(Icons.groups, color: AppColors.brand))
            : UserAvatar(
                name: conversation.name,
                radius: 20,
                imageUrl: conversation.otherAvatarUrl),
      ),
      title: Text(
        conversation.name.isEmpty ? 'Conversation' : conversation.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600),
      ),
      subtitle: Text(
        conversation.preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(relativeTime(conversation.lastAt),
              style:
                  TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: const BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              child: Text('$unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// The right pane: the active conversation's messages plus a composer.
class _ThreadPane extends StatelessWidget {
  const _ThreadPane({
    required this.state,
    required this.conversation,
    required this.online,
    this.showBack = false,
  });
  final _ChatPageState state;
  final Conversation? conversation;
  final Set<int> online;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (conversation == null) {
      return _Panel(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.forum_outlined,
                  size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('Select a conversation',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    final Conversation c = conversation!;
    final bool dmOnline = !c.isGroup &&
        c.otherUserId != null &&
        online.contains(c.otherUserId);
    return _Panel(
      child: Column(
        children: <Widget>[
          _ThreadHeader(
              state: state,
              conversation: c,
              online: dmOnline,
              showBack: showBack),
          const Divider(height: 1),
          Expanded(
            child: state._loadingMessages
                ? const Center(child: CircularProgressIndicator())
                : state._messages.isEmpty
                    ? Center(
                        child: Text('No messages yet. Say hello!',
                            style:
                                TextStyle(color: scheme.onSurfaceVariant)))
                    : ListView.builder(
                        controller: state._scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        itemCount: state._messages.length,
                        itemBuilder: (BuildContext context, int i) {
                          final ChatMessage m = state._messages[i];
                          final bool isMine = m.senderId == state._myId;
                          return _MessageBubble(
                            message: m,
                            isMine: isMine,
                            isGroup: c.isGroup,
                            token: state._token,
                            repo: state._repo,
                            myId: state._myId,
                            reactions: state._reactions[m.id],
                            onReact: (String emoji) =>
                                state._toggleReaction(m.id, emoji),
                            onLongPress: () =>
                                state._showMessageActions(m, isMine),
                          );
                        },
                      ),
          ),
          if (state._typingName != null) _TypingRow(name: state._typingName!),
          if (state._editingId != null)
            _EditBanner(onCancel: state._cancelEdit),
          _Composer(state: state),
          if (state._emojiOpen) _EmojiPanel(onPick: state._insertEmoji),
        ],
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.state,
    required this.conversation,
    required this.online,
    required this.showBack,
  });
  final _ChatPageState state;
  final Conversation conversation;
  final bool online;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: <Widget>[
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: state._back,
            ),
          _PresenceAvatar(
            online: online,
            child: conversation.isGroup
                ? const CircleAvatar(
                    backgroundColor: AppColors.brand,
                    child: Icon(Icons.groups, color: Colors.white, size: 20))
                : UserAvatar(
                    name: conversation.name,
                    radius: 18,
                    imageUrl: conversation.otherAvatarUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  conversation.name.isEmpty
                      ? 'Conversation'
                      : conversation.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (!conversation.isGroup)
                  Text(online ? 'Online' : 'Offline',
                      style: TextStyle(
                          fontSize: 11,
                          color: online
                              ? const Color(0xFF22C55E)
                              : scheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Voice call',
            icon: const Icon(Icons.call),
            onPressed: () => state._startCall('audio'),
          ),
          IconButton(
            tooltip: 'Video call',
            icon: const Icon(Icons.videocam),
            onPressed: () => state._startCall('video'),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.state});
  final _ChatPageState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Emoji',
            icon: const Icon(Icons.emoji_emotions_outlined),
            onPressed: state._toggleEmoji,
          ),
          IconButton(
            tooltip: 'Attach file',
            icon: const Icon(Icons.attach_file),
            onPressed: state._sending ? null : state._sendFile,
          ),
          Expanded(
            child: TextField(
              controller: state._composer,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onChanged: (_) => state._handleTyping(),
              onSubmitted: (_) => state._sendText(),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Send',
            icon: const Icon(Icons.send),
            onPressed: state._sending ? null : state._sendText,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isGroup,
    required this.token,
    required this.repo,
    required this.myId,
    required this.onReact,
    required this.onLongPress,
    this.reactions,
  });
  final ChatMessage message;
  final bool isMine;
  final bool isGroup;
  final String? token;
  final ChatRepository repo;
  final int? myId;
  final Map<String, Set<int>>? reactions;
  final ValueChanged<String> onReact;
  final VoidCallback onLongPress;

  String get _url => repo.attachmentUrl(message.id, token ?? '');

  Future<void> _download() async {
    if (token == null) {
      return;
    }
    await launchUrl(Uri.parse(_url), webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color bubble =
        isMine ? AppColors.brand : scheme.surfaceContainerHighest;
    final Color fg = isMine ? Colors.white : scheme.onSurface;
    final List<MapEntry<String, Set<int>>> chips = (reactions ??
            const <String, Set<int>>{})
        .entries
        .where((MapEntry<String, Set<int>> e) => e.value.isNotEmpty)
        .toList();
    final bool showAvatar = isGroup && !isMine;
    final Widget content = Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              margin: const EdgeInsets.only(top: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubble,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: <Widget>[
                  if (isGroup && !isMine && message.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(message.senderName!,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: fg.withValues(alpha: 0.85))),
                    ),
                  if (message.isImage && token != null)
                    _ImageContent(
                        url: _url, onTap: () => _showImageLightbox(context, _url)),
                  if (message.hasAttachment && !message.isImage)
                    _FileContent(
                        message: message, fg: fg, onTap: _download),
                  if (message.body.isNotEmpty)
                    Padding(
                      padding:
                          EdgeInsets.only(top: message.hasAttachment ? 6 : 0),
                      child: Text(message.body, style: TextStyle(color: fg)),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (message.edited)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text('edited',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: fg.withValues(alpha: 0.6))),
                        ),
                      Text(
                        TimeOfDay.fromDateTime(message.createdAt.toLocal())
                            .format(context),
                        style: TextStyle(
                            fontSize: 10, color: fg.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                spacing: 4,
                children: <Widget>[
                  for (final MapEntry<String, Set<int>> e in chips)
                    _ReactionChip(
                      emoji: e.key,
                      count: e.value.length,
                      mine: myId != null && e.value.contains(myId),
                      onTap: () => onReact(e.key),
                    ),
                ],
              ),
            ),
        ],
      );

    if (!showAvatar) {
      return Align(alignment: Alignment.centerLeft, child: content);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 4),
            child: UserAvatar(
                name: message.senderName ?? '',
                radius: 13,
                imageUrl: message.senderAvatarUrl),
          ),
          Flexible(child: content),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.mine,
    required this.onTap,
  });
  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: mine
              ? AppColors.brand.withValues(alpha: 0.18)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: mine ? Border.all(color: AppColors.brand) : null,
        ),
        child: Text('$emoji $count', style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

/// Opens a full-screen, pinch-zoomable view of an image attachment.
void _showImageLightbox(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (BuildContext dialog) => GestureDetector(
      onTap: () => Navigator.of(dialog).pop(),
      child: Stack(
        children: <Widget>[
          InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image.network(url,
                  errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                      const Icon(Icons.broken_image_outlined,
                          color: Colors.white, size: 48)),
            ),
          ),
          Positioned(
            top: 24,
            right: 24,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(dialog).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.url, required this.onTap});
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileContent extends StatelessWidget {
  const _FileContent(
      {required this.message, required this.fg, required this.onTap});
  final ChatMessage message;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.insert_drive_file_outlined, color: fg, size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(message.attachmentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fg, fontWeight: FontWeight.w600)),
                Text(message.sizeLabel,
                    style: TextStyle(
                        color: fg.withValues(alpha: 0.75), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps an avatar with a green online dot when [online].
class _PresenceAvatar extends StatelessWidget {
  const _PresenceAvatar({required this.child, required this.online});
  final Widget child;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        if (online)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Theme.of(context).colorScheme.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// A banner shown above the composer while editing a message.
class _EditBanner extends StatelessWidget {
  const _EditBanner({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      color: scheme.surfaceContainerHighest,
      child: Row(
        children: <Widget>[
          Icon(Icons.edit_outlined, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Editing message')),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// The "X is typing…" hint shown above the composer.
class _TypingRow extends StatelessWidget {
  const _TypingRow({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('$name is typing…',
            style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

const List<String> _emojis = <String>[
  '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😎', //
  '🤩', '🥳', '😇', '🙂', '😉', '😌', '😜', '🤔', //
  '😐', '😴', '😢', '😭', '😤', '😠', '🥺', '😅', //
  '👍', '👎', '👌', '🙏', '👏', '🙌', '💪', '🔥', //
  '✨', '🎉', '❤️', '🧡', '💛', '💚', '💙', '💜', //
  '💯', '✅', '❌', '⚡', '⭐', '💡', '📌', '🚀', //
];

/// A compact emoji grid that inserts the picked emoji into the composer.
class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: GridView.count(
        crossAxisCount: 8,
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          for (final String e in _emojis)
            InkWell(
              onTap: () => onPick(e),
              borderRadius: BorderRadius.circular(8),
              child: Center(
                  child: Text(e, style: const TextStyle(fontSize: 22))),
            ),
        ],
      ),
    );
  }
}

/// A frosted surface used for both panes.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
