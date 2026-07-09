import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/mentions.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/avatar_crop_dialog.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/chat_member.dart';
import '../../data/enums/user_status.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_reaction.dart';
import '../../data/models/conversation.dart';
import '../../data/models/link_preview.dart';
import '../../data/models/team_member.dart';
import '../../data/models/user_presence.dart';
import '../../data/repositories/chat_repository.dart';
import '../../providers/auth_provider.dart';
import '../team/providers/team_providers.dart';
import 'call/call_actions.dart';
import 'providers/chat_providers.dart';
import 'screen_capture/screen_capture.dart';
import 'widgets/giphy_picker.dart';
import 'widgets/group_members_dialog.dart';
import 'widgets/new_conversation_dialog.dart';
import 'widgets/thread_sheet.dart';

/// Emojis offered in the quick-reaction row of the message action sheet.
const List<String> _quickReactions = <String>[
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🙏',
  '🎉',
  '🔥',
];

final RegExp _urlRe = RegExp(r'https?://[^\s]+');
final RegExp _latLngRe = RegExp(r'q=(-?\d+\.?\d*),(-?\d+\.?\d*)');

/// The first http(s) URL in [text], or null.
String? _firstUrl(String text) => _urlRe.firstMatch(text)?.group(0);

bool _isMapUrl(String url) =>
    url.contains('google.com/maps') || url.contains('maps.google');

/// Whether [url] points directly at an image (incl. animated GIFs).
bool _isImageUrl(String url) {
  final String u = url.split('?').first.toLowerCase();
  return u.endsWith('.gif') ||
      u.endsWith('.png') ||
      u.endsWith('.jpg') ||
      u.endsWith('.jpeg') ||
      u.endsWith('.webp');
}

/// Parses `q=lat,lng` from a shared map URL.
(double, double)? _latLng(String url) {
  final RegExpMatch? m = _latLngRe.firstMatch(url);
  if (m == null) {
    return null;
  }
  final double? lat = double.tryParse(m.group(1)!);
  final double? lng = double.tryParse(m.group(2)!);
  return (lat == null || lng == null) ? null : (lat, lng);
}

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
  List<ChatMessage> _pinned = <ChatMessage>[];
  Map<int, Map<String, Set<int>>> _reactions = <int, Map<String, Set<int>>>{};
  int? _editingId;
  ChatMessage? _replyTarget;
  DateTime? _otherReadAt;
  bool _loadingMessages = false;
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;
  bool _sending = false;
  bool _emojiOpen = false;
  final Map<int, String> _typingUsers = <int, String>{};
  final Map<int, Timer> _typingClear = <int, Timer>{};
  DateTime? _lastTypingSent;
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  int _recSeconds = 0;
  Timer? _recTimer;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  int? get _myId => ref.read(authControllerProvider).asData?.value.user?.id;
  String? get _token => ref.read(authControllerProvider).asData?.value.token;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    for (final Timer t in _typingClear.values) {
      t.cancel();
    }
    _recTimer?.cancel();
    _recorder.dispose();
    _scroll.removeListener(_onScroll);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _recLabel =>
      '${_recSeconds ~/ 60}:${(_recSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording(send: true);
      return;
    }
    if (_selectedId == null) {
      return;
    }
    if (!await _recorder.hasPermission()) {
      _err('Microphone permission is required to record.');
      return;
    }
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.opus),
        path: '',
      );
      setState(() {
        _recording = true;
        _recSeconds = 0;
        _emojiOpen = false;
      });
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recSeconds++);
        }
      });
    } catch (e) {
      _err('Could not start recording: $e');
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    _recTimer?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    setState(() => _recording = false);
    if (!send || path == null || _selectedId == null) {
      return;
    }
    setState(() => _sending = true);
    try {
      final Uint8List? bytes = await _fetchBytes(path);
      if (bytes != null && bytes.isNotEmpty) {
        _appendMine(
          await _repo.uploadFile(
            _selectedId!,
            bytes,
            'voice-message.webm',
            contentType: 'audio/webm',
          ),
        );
      }
    } catch (e) {
      _err('Could not send voice message: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  /// Reads the bytes of a (web) blob: URL produced by the recorder.
  Future<Uint8List?> _fetchBytes(String url) async {
    try {
      final Response<List<int>> res = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final List<int>? data = res.data;
      return data == null ? null : Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareLocation() async {
    if (_selectedId == null) {
      return;
    }
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _err('Location permission denied.');
        return;
      }
      final Position pos = await Geolocator.getCurrentPosition();
      final String mapUrl =
          'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
      _appendMine(await _repo.sendText(_selectedId!, mapUrl));
    } catch (e) {
      _err('Could not get your location: $e');
    }
  }

  Future<void> _captureScreenAndSend() async {
    if (_selectedId == null) {
      return;
    }
    final Uint8List? bytes = await captureScreen();
    if (bytes == null || bytes.isEmpty) {
      _err('Screen capture was cancelled or is unavailable.');
      return;
    }
    setState(() => _sending = true);
    try {
      _appendMine(
        await _repo.uploadFile(
          _selectedId!,
          bytes,
          'screenshot.png',
          contentType: 'image/png',
        ),
      );
    } catch (e) {
      _err('Could not send screenshot: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _uploadGroupAvatar(int conversationId) async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.first.bytes;
    if (result == null || bytes == null || !mounted) {
      return;
    }
    final cropped = await cropAvatar(context, bytes);
    if (cropped == null) {
      return;
    }
    try {
      await ref
          .read(chatRepositoryProvider)
          .uploadGroupAvatar(conversationId, cropped);
      ref.invalidate(conversationsProvider);
    } catch (e) {
      _err('Could not update group photo: $e');
    }
  }

  /// Opens the group info sheet (member list + admin add/remove + leave). If the
  /// current user leaves, the open thread is closed.
  Future<void> _openGroupInfo(Conversation conv) async {
    final bool left = await showGroupMembers(context, conv);
    if (left && mounted) {
      _back();
      ref.invalidate(conversationsProvider);
    }
  }

  Future<void> _pickGif() async {
    if (_selectedId == null) {
      return;
    }
    final String? url = await showGiphyPicker(context, ref);
    if (url == null || url.isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      _appendMine(await _repo.sendText(_selectedId!, url));
    } catch (e) {
      _err('Could not send GIF: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
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
      final List<ChatMessage> older = await _repo.messages(
        _selectedId!,
        limit: _pageSize,
        offset: _messages.length,
      );
      if (!mounted) {
        return;
      }
      final double prevExtent = _scroll.hasClients
          ? _scroll.position.maxScrollExtent
          : 0;
      final double prevPixels = _scroll.hasClients
          ? _scroll.position.pixels
          : 0;
      setState(() {
        _messages = <ChatMessage>[...older.reversed, ..._messages];
        _hasMoreOlder = older.length == _pageSize;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(
            prevPixels + (_scroll.position.maxScrollExtent - prevExtent),
          );
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
        final Map<String, Set<int>> forMsg = _reactions.putIfAbsent(
          messageId,
          () => <String, Set<int>>{},
        );
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
      final Map<String, Set<int>> forMsg = _reactions.putIfAbsent(
        messageId,
        () => <String, Set<int>>{},
      );
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
        final ChatMessage msg = ChatMessage.fromJson(
          e['message'] as Map<String, dynamic>,
        );
        ref.invalidate(conversationsProvider);
        if (msg.conversationId == _selectedId) {
          if (!_messages.any((ChatMessage m) => m.id == msg.id)) {
            setState(() {
              _messages = <ChatMessage>[..._messages, msg];
              _typingClear.remove(msg.senderId)?.cancel();
              _typingUsers.remove(msg.senderId);
            });
            _scrollToBottom();
          }
          _repo.markRead(msg.conversationId);
        }
      case 'typing':
        if (e['conversation_id'] == _selectedId && e['from_id'] != _myId) {
          final int? fromId = e['from_id'] as int?;
          final String? name = e['from_name'] as String?;
          if (fromId == null || name == null || name.isEmpty) {
            return;
          }
          setState(() => _typingUsers[fromId] = name);
          _typingClear.remove(fromId)?.cancel();
          _typingClear[fromId] = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() => _typingUsers.remove(fromId));
            }
          });
        }
      case 'message_deleted':
        if (e['conversation_id'] == _selectedId) {
          final int id = e['id'] as int;
          setState(
            () => _messages = _messages
                .where((ChatMessage m) => m.id != id)
                .toList(),
          );
        }
        ref.invalidate(conversationsProvider);
      case 'message_edited':
        if (e['conversation_id'] == _selectedId) {
          final ChatMessage edited = ChatMessage.fromJson(
            e['message'] as Map<String, dynamic>,
          );
          setState(
            () => _messages = _messages
                .map((ChatMessage m) => m.id == edited.id ? edited : m)
                .toList(),
          );
        }
      case 'reaction':
        if (e['conversation_id'] == _selectedId) {
          _applyReactionEvent(e);
        }
      case 'pin':
        if (e['conversation_id'] == _selectedId) {
          final int id = e['message_id'] as int;
          final bool pinned = e['pinned'] as bool? ?? false;
          setState(
            () => _messages = _messages
                .map(
                  (ChatMessage m) =>
                      m.id == id ? m.copyWith(pinned: pinned) : m,
                )
                .toList(),
          );
          _refreshPinned();
        }
      case 'read':
        if (e['conversation_id'] == _selectedId && e['user_id'] != _myId) {
          final DateTime at = DateTime.parse(e['read_at'] as String);
          setState(() => _otherReadAt = at);
        }
      case 'members':
        ref.invalidate(conversationsProvider);
        final int? cid = e['conversation_id'] as int?;
        if (cid != null) {
          ref.invalidate(conversationMembersProvider(cid));
        }
    }
  }

  Future<void> _refreshPinned() async {
    if (_selectedId == null) {
      return;
    }
    final int id = _selectedId!;
    final List<ChatMessage> pins = await _repo.pinned(id);
    if (mounted && _selectedId == id) {
      setState(() => _pinned = pins);
    }
  }

  void _onComposerChanged() {
    _handleTyping();
    setState(() {}); // refresh the mic / send toggle
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

  Future<void> _deleteMessage(int id) async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Delete message'),
            content: const Text('Delete this message for everyone?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) {
      return;
    }
    try {
      await _repo.deleteMessage(id);
      setState(
        () =>
            _messages = _messages.where((ChatMessage m) => m.id != id).toList(),
      );
      ref.invalidate(conversationsProvider);
    } catch (e) {
      _err('Could not delete: $e');
    }
  }

  Future<void> _open(int id) async {
    final Conversation? conv = _selectedFrom(
      ref.read(conversationsProvider).asData?.value ?? const <Conversation>[],
    );
    setState(() {
      _selectedId = id;
      _messages = <ChatMessage>[];
      _pinned = <ChatMessage>[];
      _reactions = <int, Map<String, Set<int>>>{};
      _editingId = null;
      _replyTarget = null;
      _otherReadAt = null;
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
      final List<ChatMessage> pins = await _repo.pinned(id);
      if (mounted && _selectedId == id) {
        setState(() {
          _reactions = _buildReactions(rx);
          _pinned = pins;
        });
      }
      // Read receipts: in a DM, find the other member's last-read time.
      if (conv != null && !conv.isGroup) {
        final List<ChatMember> members = await _repo.members(id);
        if (mounted && _selectedId == id) {
          DateTime? other;
          for (final ChatMember m in members) {
            if (m.userId != _myId && m.lastReadAt != null) {
              other = m.lastReadAt;
            }
          }
          setState(() => _otherReadAt = other);
        }
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
    final int? replyTo = _replyTarget?.id;
    final List<TeamMember> team =
        ref.read(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    final List<int> mentions = parseMentions(body, mentionTokenMap(team));
    _composer.clear();
    setState(() {
      _sending = true;
      _replyTarget = null;
    });
    try {
      _appendMine(
        await _repo.sendText(
          _selectedId!,
          body,
          replyTo: replyTo,
          mentions: mentions,
        ),
      );
    } catch (e) {
      _err('Could not send: $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  /// Inserts an @mention token at the composer's cursor, picked from the team.
  Future<void> _insertMention() async {
    final List<TeamMember> team =
        ref.read(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    if (team.isEmpty) {
      return;
    }
    final TeamMember? picked = await showDialog<TeamMember>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Mention someone'),
        children: <Widget>[
          for (final TeamMember m in team)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(
                  name: m.name.isEmpty ? m.email : m.name,
                  radius: 16,
                  imageUrl: m.avatarUrl,
                ),
                title: Text(m.name.isEmpty ? m.email : m.name),
              ),
            ),
        ],
      ),
    );
    if (picked == null) {
      return;
    }
    final List<String> parts = picked.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();
    final String token = parts.isNotEmpty
        ? parts.first.toLowerCase()
        : picked.email.split('@').first.toLowerCase();
    final TextSelection sel = _composer.selection;
    final String base = _composer.text;
    final int start = sel.start >= 0 ? sel.start : base.length;
    final int end = sel.end >= 0 ? sel.end : base.length;
    final String insert = '@$token ';
    _composer.text = base.replaceRange(start, end, insert);
    _composer.selection = TextSelection.collapsed(
      offset: start + insert.length,
    );
    setState(() {});
  }

  void _startReply(ChatMessage m) {
    setState(() {
      _replyTarget = m;
      _editingId = null;
      _emojiOpen = false;
    });
  }

  /// Opens [m]'s thread; refreshes its reply count from the sheet on close.
  Future<void> _openThread(ChatMessage m) async {
    final int? count = await showThreadSheet(context, m);
    if (count != null && mounted) {
      setState(() {
        _messages = _messages
            .map(
              (ChatMessage x) =>
                  x.id == m.id ? x.copyWith(replyCount: count) : x,
            )
            .toList();
      });
    }
  }

  void _cancelReply() => setState(() => _replyTarget = null);

  Future<void> _setPin(ChatMessage m) async {
    try {
      await _repo.setPin(m.id, pinned: !m.pinned);
    } catch (e) {
      _err('Could not pin: $e');
    }
  }

  Future<void> _forward(ChatMessage m) async {
    final List<Conversation> convos =
        ref.read(conversationsProvider).asData?.value ?? const <Conversation>[];
    final int? targetId = await showDialog<int>(
      context: context,
      builder: (BuildContext dialog) => SimpleDialog(
        title: const Text('Forward to'),
        children: <Widget>[
          for (final Conversation c in convos)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, c.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: c.isGroup
                    ? const CircleAvatar(child: Icon(Icons.groups))
                    : UserAvatar(
                        name: c.name,
                        imageUrl: c.otherAvatarUrl,
                        radius: 18,
                      ),
                title: Text(c.name.isEmpty ? 'Conversation' : c.name),
              ),
            ),
        ],
      ),
    );
    if (targetId == null) {
      return;
    }
    try {
      await _repo.forward(m.id, targetId);
      ref.invalidate(conversationsProvider);
      if (targetId == _selectedId) {
        // The forwarded copy arrives over the socket for the open chat.
      } else if (mounted) {
        context.showSuccess('Message forwarded');
      }
    } catch (e) {
      _err('Forward failed: $e');
    }
  }

  void _startEdit(ChatMessage m) {
    setState(() {
      _editingId = m.id;
      _emojiOpen = false;
    });
    _composer.text = m.body;
    _composer.selection = TextSelection.collapsed(
      offset: _composer.text.length,
    );
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
      setState(
        () => _messages = _messages
            .map((ChatMessage m) => m.id == id ? updated : m)
            .toList(),
      );
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
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(sheet);
                _startReply(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(m.hasThread ? 'Open thread' : 'Reply in thread'),
              onTap: () {
                Navigator.pop(sheet);
                _openThread(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(sheet);
                _forward(m);
              },
            ),
            ListTile(
              leading: Icon(
                m.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(m.pinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(sheet);
                _setPin(m);
              },
            ),
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
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
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

  /// Opens the attachment menu (Photo / Video / Document).
  Future<void> _openAttachMenu() async {
    if (_selectedId == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _AttachOption(
              icon: Icons.image_outlined,
              color: AppColors.brand,
              label: 'Photo',
              subtitle: 'JPG, PNG, GIF',
              onTap: () {
                Navigator.pop(sheet);
                _pickAndSend(FileType.image);
              },
            ),
            _AttachOption(
              icon: Icons.videocam_outlined,
              color: AppColors.rose,
              label: 'Video',
              subtitle: 'MP4, WebM, MOV',
              onTap: () {
                Navigator.pop(sheet);
                _pickAndSend(FileType.video);
              },
            ),
            _AttachOption(
              icon: Icons.insert_drive_file_outlined,
              color: AppColors.teal,
              label: 'Document',
              subtitle: 'PDF, docs, any file',
              onTap: () {
                Navigator.pop(sheet);
                _pickAndSend(FileType.any);
              },
            ),
            _AttachOption(
              icon: Icons.location_on_outlined,
              color: AppColors.green,
              label: 'Location',
              subtitle: 'Share your current location',
              onTap: () {
                Navigator.pop(sheet);
                _shareLocation();
              },
            ),
            _AttachOption(
              icon: Icons.screenshot_monitor_outlined,
              color: AppColors.violet,
              label: 'Screenshot',
              subtitle: 'Capture a screen, window or tab',
              onTap: () {
                Navigator.pop(sheet);
                _captureScreenAndSend();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static const int _maxUploadBytes = 100 * 1024 * 1024; // 100 MB

  Future<void> _pickAndSend(FileType type) async {
    if (_selectedId == null) {
      return;
    }
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: type,
      withData: true,
    );
    final bytes = result?.files.first.bytes;
    if (result == null || bytes == null) {
      return;
    }
    if (bytes.length > _maxUploadBytes) {
      _err('That file is too large (max 100 MB). Try a smaller one.');
      return;
    }
    setState(() => _sending = true);
    try {
      _appendMine(
        await _repo.uploadFile(_selectedId!, bytes, result.files.first.name),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
      ref.read(conversationsProvider).asData?.value ?? const <Conversation>[],
    );
    await startCall(context, ref, _selectedId!, mode, title: conv?.name ?? '');
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

  Future<void> _browseChannels() async {
    final int? id = await browsePublicChannels(context, ref);
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
    ref.listen<AsyncValue<Map<String, dynamic>>>(chatEventsProvider, (
      AsyncValue<Map<String, dynamic>>? prev,
      AsyncValue<Map<String, dynamic>> next,
    ) {
      next.whenData(_onEvent);
    });

    final List<Conversation> convos =
        ref.watch(conversationsProvider).asData?.value ??
        const <Conversation>[];
    final Map<int, UserPresence> presence =
        ref.watch(presenceProvider).asData?.value ??
        const <int, UserPresence>{};
    final Conversation? selected = _selectedFrom(convos);
    final bool wide = MediaQuery.sizeOf(context).width >= 820;

    if (wide) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PageHeader(
              title: 'Chat',
              subtitle: 'Team messaging, channels and calls',
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: 320,
                    child: _ListPane(
                      state: this,
                      convos: convos,
                      presence: presence,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ThreadPane(
                      state: this,
                      conversation: selected,
                      presence: presence,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _selectedId == null
          ? _ListPane(state: this, convos: convos, presence: presence)
          : _ThreadPane(
              state: this,
              conversation: selected,
              presence: presence,
              showBack: true,
            ),
    );
  }
}

/// The left pane: conversation list with a "new chat" menu.
class _ListPane extends StatelessWidget {
  const _ListPane({
    required this.state,
    required this.convos,
    required this.presence,
  });
  final _ChatPageState state;
  final List<Conversation> convos;
  final Map<int, UserPresence> presence;

  /// The status dot to show for a conversation: the DM partner's effective
  /// status, or null for groups.
  UserStatus? _statusFor(Conversation c) {
    if (c.isGroup || c.otherUserId == null) {
      return null;
    }
    return presence[c.otherUserId]?.effective ?? UserStatus.offline;
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: <Widget>[
                const Text(
                  'Chat',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'New conversation',
                  icon: const Icon(Icons.edit_square),
                  onSelected: (String v) => switch (v) {
                    'dm' => state._newDm(),
                    'group' => state._newGroup(),
                    _ => state._browseChannels(),
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'dm',
                          child: ListTile(
                            leading: Icon(Icons.person_add_alt_1),
                            title: Text('New message'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'group',
                          child: ListTile(
                            leading: Icon(Icons.group_add),
                            title: Text('New group'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'browse',
                          child: ListTile(
                            leading: Icon(Icons.tag),
                            title: Text('Browse channels'),
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: convos.isEmpty
                ? const EmptyState(
                    icon: Icons.forum_outlined,
                    message: 'No conversations yet. Start a new chat.',
                  )
                : ListView.builder(
                    itemCount: convos.length,
                    itemBuilder: (BuildContext context, int i) =>
                        _ConversationTile(
                          conversation: convos[i],
                          selected: convos[i].id == state._selectedId,
                          status: _statusFor(convos[i]),
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
    required this.status,
    required this.onTap,
  });
  final Conversation conversation;
  final bool selected;
  final UserStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int unread = conversation.unreadCount;
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: _PresenceAvatar(
        status: status,
        child: _ConvAvatar(conversation: conversation, radius: 20),
      ),
      title: Row(
        children: <Widget>[
          if (conversation.isGroup)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.groups,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
            ),
          Expanded(
            child: Text(
              conversation.name.isEmpty ? 'Conversation' : conversation.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
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
          Text(
            relativeTime(conversation.lastAt),
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: const BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
    required this.presence,
    this.showBack = false,
  });
  final _ChatPageState state;
  final Conversation? conversation;
  final Map<int, UserPresence> presence;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    if (conversation == null) {
      return _Panel(
        child: const EmptyState(
          icon: Icons.forum_outlined,
          message: 'Select a conversation to start chatting.',
        ),
      );
    }
    final Conversation c = conversation!;
    final UserPresence? otherPres = c.isGroup ? null : presence[c.otherUserId];
    final bool otherOnline = otherPres?.online ?? false;
    return _Panel(
      child: Column(
        children: <Widget>[
          _ThreadHeader(
            state: state,
            conversation: c,
            other: otherPres,
            showBack: showBack,
          ),
          const Divider(height: 1),
          if (state._pinned.isNotEmpty)
            _PinnedBanner(
              message: state._pinned.first,
              count: state._pinned.length,
              onUnpin: () => state._setPin(state._pinned.first),
            ),
          Expanded(
            child: state._loadingMessages
                ? const LoadingView()
                : state._messages.isEmpty
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    message: 'No messages yet. Say hello!',
                  )
                : ListView.builder(
                    controller: state._scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    itemCount: state._messages.length,
                    itemBuilder: (BuildContext context, int i) {
                      final ChatMessage m = state._messages[i];
                      final bool isMine = m.senderId == state._myId;
                      final ChatMessage? prev = i > 0
                          ? state._messages[i - 1]
                          : null;
                      final bool firstOfGroup =
                          prev == null ||
                          prev.senderId != m.senderId ||
                          m.createdAt.difference(prev.createdAt).inMinutes >= 5;
                      final bool seen =
                          isMine &&
                          !c.isGroup &&
                          state._otherReadAt != null &&
                          !m.createdAt.isAfter(state._otherReadAt!);
                      return _MessageBubble(
                        message: m,
                        isMine: isMine,
                        isGroup: c.isGroup,
                        token: state._token,
                        repo: state._repo,
                        myId: state._myId,
                        seen: seen,
                        otherOnline: otherOnline,
                        firstOfGroup: firstOfGroup,
                        reactions: state._reactions[m.id],
                        onReact: (String emoji) =>
                            state._toggleReaction(m.id, emoji),
                        onLongPress: () => state._showMessageActions(m, isMine),
                        onOpenThread: () => state._openThread(m),
                      );
                    },
                  ),
          ),
          if (state._typingUsers.isNotEmpty)
            _TypingRow(names: state._typingUsers.values.toList()),
          if (state._replyTarget != null)
            _ReplyBanner(
              message: state._replyTarget!,
              onCancel: state._cancelReply,
            ),
          if (state._editingId != null)
            _EditBanner(onCancel: state._cancelEdit),
          _Composer(state: state),
          if (state._emojiOpen) _EmojiPanel(controller: state._composer),
        ],
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.state,
    required this.conversation,
    required this.other,
    required this.showBack,
  });
  final _ChatPageState state;
  final Conversation conversation;
  final UserPresence? other;
  final bool showBack;

  /// The presence sub-title for a DM: status + message, or "last seen …".
  String _subtitle() {
    final UserPresence? p = other;
    if (p == null) {
      return 'Offline';
    }
    if (p.online) {
      return p.statusMessage.isNotEmpty
          ? '${p.status.label} · ${p.statusMessage}'
          : p.status.label;
    }
    if (p.lastSeen != null) {
      return 'Last seen ${relativeTime(p.lastSeen!)}';
    }
    return 'Offline';
  }

  @override
  Widget build(BuildContext context) {
    final UserStatus? status = conversation.isGroup
        ? null
        : (other?.effective ?? UserStatus.offline);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: <Widget>[
          if (showBack)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: state._back,
            ),
          if (conversation.isGroup)
            GestureDetector(
              onTap: () => state._uploadGroupAvatar(conversation.id),
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  _ConvAvatar(conversation: conversation, radius: 18),
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: AppColors.brand,
                      child: Icon(
                        Icons.camera_alt,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _PresenceAvatar(
              status: status,
              child: _ConvAvatar(conversation: conversation, radius: 18),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!conversation.isGroup)
                  Text(
                    _subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: (status ?? UserStatus.offline).color,
                    ),
                  )
                else if (conversation.memberCount > 0)
                  Text(
                    '${conversation.memberCount} '
                    'member${conversation.memberCount == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (conversation.isGroup)
            IconButton(
              tooltip: 'Group info & members',
              icon: const Icon(Icons.group_outlined),
              onPressed: () => state._openGroupInfo(conversation),
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
    if (state._recording) {
      return _recordingBar(context);
    }
    final bool empty = state._composer.text.trim().isEmpty;
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
            tooltip: 'GIFs & stickers',
            icon: const Icon(Icons.gif_box_outlined),
            onPressed: state._sending ? null : state._pickGif,
          ),
          IconButton(
            tooltip: 'Attach',
            icon: const Icon(Icons.attach_file),
            onPressed: state._sending ? null : state._openAttachMenu,
          ),
          IconButton(
            tooltip: 'Mention',
            icon: const Icon(Icons.alternate_email),
            onPressed: state._sending ? null : state._insertMention,
          ),
          Expanded(
            child: TextField(
              controller: state._composer,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onChanged: (_) => state._onComposerChanged(),
              onSubmitted: (_) => state._sendText(),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                filled: true,
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
          const SizedBox(width: 6),
          // A mic button when there's nothing typed; otherwise the send button.
          if (empty && state._editingId == null)
            IconButton.filled(
              tooltip: 'Record voice message',
              icon: const Icon(Icons.mic),
              onPressed: state._sending ? null : state._toggleRecording,
            )
          else
            IconButton.filled(
              tooltip: 'Send',
              icon: const Icon(Icons.send),
              onPressed: state._sending ? null : state._sendText,
            ),
        ],
      ),
    );
  }

  Widget _recordingBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: Row(
        children: <Widget>[
          const _PulsingDot(),
          const SizedBox(width: 10),
          Text(
            'Recording  ${state._recLabel}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => state._stopRecording(send: false),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            tooltip: 'Send voice message',
            icon: const Icon(Icons.send),
            onPressed: () => state._stopRecording(send: true),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Renders a message body with valid @mentions highlighted.
class _MentionBody extends ConsumerWidget {
  const _MentionBody({
    required this.body,
    required this.color,
    required this.mine,
  });

  final String body;
  final Color color;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TeamMember> team =
        ref.watch(teamMembersProvider).asData?.value ?? const <TeamMember>[];
    if (!body.contains('@') || team.isEmpty) {
      return Text(body, style: TextStyle(color: color));
    }
    final Set<String> tokens = mentionTokenMap(team).keys.toSet();
    // On own (colored) bubbles keep the text colour but bold the mention;
    // otherwise use the brand accent.
    final Color highlight = mine ? color : AppColors.brand;
    return Text.rich(
      TextSpan(children: mentionSpans(body, tokens, highlight)),
      style: TextStyle(color: color),
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
    required this.onOpenThread,
    this.seen = false,
    this.otherOnline = false,
    this.firstOfGroup = true,
    this.reactions,
  });
  final ChatMessage message;
  final bool isMine;
  final bool isGroup;
  final bool firstOfGroup;
  final String? token;
  final ChatRepository repo;
  final int? myId;
  final bool seen;
  final bool otherOnline;
  final Map<String, Set<int>>? reactions;
  final ValueChanged<String> onReact;
  final VoidCallback onLongPress;
  final VoidCallback onOpenThread;

  String get _url => repo.attachmentUrl(message.id, token ?? '');

  Future<void> _download() async {
    if (token == null) {
      return;
    }
    await launchUrl(Uri.parse(_url), webOnlyWindowName: '_blank');
  }

  /// Whether the body is just a single media URL (image/GIF or map) — used to
  /// render it as media and hide the raw URL text.
  bool get _pureMediaUrl {
    if (message.body.isEmpty) {
      return false;
    }
    final String? url = _firstUrl(message.body);
    return url != null &&
        message.body.trim() == url &&
        (_isImageUrl(url) || _isMapUrl(url));
  }

  /// Renders an inline image (GIF/sticker), a location card, or a link preview
  /// for a URL found in a text message (nothing when there is no URL).
  Widget _linkOrLocation(BuildContext context, Color fg) {
    if (message.body.isEmpty) {
      return const SizedBox.shrink();
    }
    final String? url = _firstUrl(message.body);
    if (url == null) {
      return const SizedBox.shrink();
    }
    final Widget child;
    if (_isImageUrl(url)) {
      child = GestureDetector(
        onTap: () => _showImageLightbox(context, url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
            child: Image.network(
              url,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      );
    } else if (_isMapUrl(url)) {
      child = _LocationCard(url: url);
    } else {
      child = _LinkPreviewCard(url: url, fg: fg);
    }
    return Padding(padding: const EdgeInsets.only(top: 6), child: child);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color bubble = isMine
        ? AppColors.brand
        : scheme.surfaceContainerHighest;
    final Color fg = isMine ? Colors.white : scheme.onSurface;
    final List<MapEntry<String, Set<int>>> chips =
        (reactions ?? const <String, Set<int>>{}).entries
            .where((MapEntry<String, Set<int>> e) => e.value.isNotEmpty)
            .toList();
    final bool showAvatar = isGroup && !isMine && firstOfGroup;
    final Widget content = Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            margin: EdgeInsets.only(top: firstOfGroup ? 4 : 1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bubble,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: <Widget>[
                if (isGroup &&
                    !isMine &&
                    firstOfGroup &&
                    message.senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      message.senderName!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                if (message.forwarded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.forward,
                          size: 12,
                          color: fg.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Forwarded',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: fg.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (message.isReply)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border(
                        left: BorderSide(
                          color: fg.withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          message.replySenderName ?? 'Reply',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: fg.withValues(alpha: 0.9),
                          ),
                        ),
                        Text(
                          ChatMessage.previewFor(
                            message.replyKind,
                            message.replyBody,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: fg.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (message.isImage && token != null)
                  _ImageContent(
                    url: _url,
                    onTap: () => _showImageLightbox(context, _url),
                  )
                else if (message.isAudio && token != null)
                  _AudioContent(url: _url, fg: fg)
                else if (message.isVideo && token != null)
                  _VideoContent(
                    message: message,
                    fg: fg,
                    onTap: () => _showVideoLightbox(context, _url),
                  )
                else if (message.hasAttachment)
                  _FileContent(message: message, fg: fg, onTap: _download),
                if (message.body.isNotEmpty && !_pureMediaUrl)
                  Padding(
                    padding: EdgeInsets.only(
                      top: message.hasAttachment ? 6 : 0,
                    ),
                    child: _MentionBody(
                      body: message.body,
                      color: fg,
                      mine: isMine,
                    ),
                  ),
                if (!message.hasAttachment) _linkOrLocation(context, fg),
                if (message.hasThread)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: InkWell(
                      onTap: onOpenThread,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.forum_outlined,
                              size: 14,
                              color: fg.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              message.replyCount == 1
                                  ? '1 reply'
                                  : '${message.replyCount} replies',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: fg.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (message.edited)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          'edited',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: fg.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    if (message.pinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.push_pin,
                          size: 11,
                          color: fg.withValues(alpha: 0.7),
                        ),
                      ),
                    Text(
                      TimeOfDay.fromDateTime(
                        message.createdAt.toLocal(),
                      ).format(context),
                      style: TextStyle(
                        fontSize: 10,
                        color: fg.withValues(alpha: 0.7),
                      ),
                    ),
                    if (isMine && !isGroup)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          // sent (single) / delivered (double) / read (blue).
                          (seen || otherOnline) ? Icons.done_all : Icons.done,
                          size: 14,
                          color: seen
                              ? const Color(0xFF7DD3FC)
                              : fg.withValues(alpha: 0.7),
                        ),
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
      final bool grouped = isGroup && !isMine;
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: grouped ? 32 : 0),
          child: content,
        ),
      );
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
              imageUrl: message.senderAvatarUrl,
            ),
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
              child: Image.network(
                url,
                errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                    const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
              ),
            ),
          ),
          Positioned(
            top: 24,
            right: 24,
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(dialog).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A video attachment shown as a tappable card with a play button; tapping
/// opens a full-screen player.
class _VideoContent extends StatelessWidget {
  const _VideoContent({
    required this.message,
    required this.fg,
    required this.onTap,
  });
  final ChatMessage message;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    message.attachmentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Video · ${message.sizeLabel}',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
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

/// Opens a full-screen player for a video attachment.
void _showVideoLightbox(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (BuildContext dialog) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.topRight,
        children: <Widget>[
          _VideoPlayerView(url: url),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(dialog).pop(),
          ),
        ],
      ),
    ),
  );
}

/// An inline video player with play/pause and a progress bar.
class _VideoPlayerView extends StatefulWidget {
  const _VideoPlayerView({required this.url});
  final String url;

  @override
  State<_VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<_VideoPlayerView> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _ready = true);
              _controller.play();
            }
          })
          .catchError((Object e) {
            if (mounted) {
              setState(() => _error = '$e');
            }
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(
      () => _controller.value.isPlaying
          ? _controller.pause()
          : _controller.play(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Could not play this video.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    if (!_ready) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio == 0
              ? 16 / 9
              : _controller.value.aspectRatio,
          child: GestureDetector(
            onTap: _toggle,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                VideoPlayer(_controller),
                if (!_controller.value.isPlaying)
                  const Icon(
                    Icons.play_circle_fill,
                    color: Colors.white70,
                    size: 64,
                  ),
              ],
            ),
          ),
        ),
        VideoProgressIndicator(_controller, allowScrubbing: true),
      ],
    );
  }
}

/// An inline audio / voice-message player with play-pause and a progress bar.
class _AudioContent extends StatefulWidget {
  const _AudioContent({required this.url, required this.fg});
  final String url;
  final Color fg;

  @override
  State<_AudioContent> createState() => _AudioContentState();
}

class _AudioContentState extends State<_AudioContent> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs =
      <StreamSubscription<dynamic>>[];
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _subs.add(
      _player.onPlayerStateChanged.listen((PlayerState s) {
        if (mounted) {
          setState(() => _playing = s == PlayerState.playing);
        }
      }),
    );
    _subs.add(
      _player.onPositionChanged.listen((Duration p) {
        if (mounted) {
          setState(() => _pos = p);
        }
      }),
    );
    _subs.add(
      _player.onDurationChanged.listen((Duration d) {
        if (mounted) {
          setState(() => _dur = d);
        }
      }),
    );
    _subs.add(
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playing = false;
            _pos = Duration.zero;
          });
        }
      }),
    );
  }

  @override
  void dispose() {
    for (final StreamSubscription<dynamic> s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final double progress = _dur.inMilliseconds == 0
        ? 0
        : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);
    return SizedBox(
      width: 220,
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: _toggle,
            child: Icon(
              _playing ? Icons.pause_circle : Icons.play_circle,
              color: widget.fg,
              size: 34,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: widget.fg.withValues(alpha: 0.25),
                  color: widget.fg,
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Icon(Icons.mic, size: 12, color: widget.fg),
                    const SizedBox(width: 4),
                    Text(
                      _dur == Duration.zero ? 'Voice message' : _fmt(_dur),
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.fg.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A rich link-preview card backed by server-side Open Graph metadata.
class _LinkPreviewCard extends ConsumerWidget {
  const _LinkPreviewCard({required this.url, required this.fg});
  final String url;
  final Color fg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LinkPreview? pv = ref.watch(linkPreviewProvider(url)).asData?.value;
    if (pv == null) {
      return const SizedBox.shrink();
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
      child: Container(
        width: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (pv.image.isNotEmpty)
              Image.network(
                pv.image,
                height: 130,
                width: 280,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (pv.site.isNotEmpty)
                    Text(
                      pv.site.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (pv.title.isNotEmpty)
                    Text(
                      pv.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (pv.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        pv.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
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

/// A shared-location card with a static map thumbnail and an open-in-maps tap.
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (double, double)? coords = _latLng(url);
    final String? map = coords == null
        ? null
        : 'https://staticmap.openstreetmap.de/staticmap.php'
              '?center=${coords.$1},${coords.$2}&zoom=15&size=280x130'
              '&markers=${coords.$1},${coords.$2},red-pushpin';
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
      child: Container(
        width: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (map != null)
              Image.network(
                map,
                height: 130,
                width: 280,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 90,
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.map_outlined,
                    color: scheme.onSurfaceVariant,
                    size: 36,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  Icon(Icons.location_on, color: scheme.primary, size: 18),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Shared location',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    'Open in Maps',
                    style: TextStyle(fontSize: 11, color: scheme.primary),
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
  const _FileContent({
    required this.message,
    required this.fg,
    required this.onTap,
  });
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
                Text(
                  message.attachmentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
                Text(
                  message.sizeLabel,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The avatar for a conversation: a DM partner's photo, a group's uploaded
/// photo, or a groups icon fallback.
class _ConvAvatar extends StatelessWidget {
  const _ConvAvatar({required this.conversation, this.radius = 20});
  final Conversation conversation;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (!conversation.isGroup) {
      return UserAvatar(
        name: conversation.name,
        radius: radius,
        imageUrl: conversation.otherAvatarUrl,
      );
    }
    if (conversation.groupAvatarUrl != null) {
      return UserAvatar(
        name: conversation.name,
        radius: radius,
        imageUrl: conversation.groupAvatarUrl,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.brand.withValues(alpha: 0.15),
      child: Icon(Icons.groups, color: AppColors.brand, size: radius),
    );
  }
}

/// Wraps an avatar with a status dot in the colour of [status] (none for null).
class _PresenceAvatar extends StatelessWidget {
  const _PresenceAvatar({required this.child, required this.status});
  final Widget child;
  final UserStatus? status;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        if (status != null)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: status!.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A sticky bar showing the conversation's pinned message(s).
class _PinnedBanner extends StatelessWidget {
  const _PinnedBanner({
    required this.message,
    required this.count,
    required this.onUnpin,
  });
  final ChatMessage message;
  final int count;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.push_pin, size: 16, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  count > 1 ? '$count pinned messages' : 'Pinned message',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                Text(
                  ChatMessage.previewFor(message.kind, message.body),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Unpin',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onUnpin,
          ),
        ],
      ),
    );
  }
}

/// A banner shown above the composer while replying to a message.
class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.message, required this.onCancel});
  final ChatMessage message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      color: scheme.surfaceContainerHighest,
      child: Row(
        children: <Widget>[
          Icon(Icons.reply, size: 16, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Replying to ${message.senderName ?? 'message'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                Text(
                  ChatMessage.previewFor(message.kind, message.body),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
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
            tooltip: 'Cancel',
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
  const _TypingRow({required this.names});
  final List<String> names;

  String get _label {
    switch (names.length) {
      case 0:
        return '';
      case 1:
        return '${names[0]} is typing…';
      case 2:
        return '${names[0]} & ${names[1]} are typing…';
      case 3:
        return '${names[0]}, ${names[1]} & ${names[2]} are typing…';
      default:
        return 'Several people are typing…';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _label,
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A row in the attachment menu (Photo / Video / Document).
class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
    );
  }
}

/// The full, searchable emoji picker. It writes directly into the composer's
/// text controller (insert at cursor + backspace), with every emoji category.
class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 300,
      child: EmojiPicker(
        textEditingController: controller,
        config: Config(
          height: 300,
          emojiViewConfig: EmojiViewConfig(
            columns: 9,
            emojiSizeMax: 26,
            backgroundColor: scheme.surface,
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: scheme.surface,
            indicatorColor: scheme.primary,
            iconColor: scheme.onSurfaceVariant,
            iconColorSelected: scheme.primary,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: scheme.surfaceContainerHighest,
            buttonColor: scheme.surfaceContainerHighest,
            buttonIconColor: scheme.onSurface,
          ),
          searchViewConfig: SearchViewConfig(backgroundColor: scheme.surface),
        ),
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
    return GlassSurface(borderRadius: 16, child: child);
  }
}
