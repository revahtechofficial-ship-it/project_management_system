import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../data/models/conversation.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dio_provider.dart';
import '../chat_socket.dart';

/// The chat repository, built from the shared Dio client (AGENTS.md §1).
final Provider<ChatRepository> chatRepositoryProvider =
    Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(dioProvider));
});

/// The current user's conversations. Invalidate to refresh.
final FutureProvider<List<Conversation>> conversationsProvider =
    FutureProvider<List<Conversation>>((ref) {
  return ref.watch(chatRepositoryProvider).conversations();
});

/// Total unread messages across all conversations (for the nav badge).
final Provider<int> chatUnreadProvider = Provider<int>((ref) {
  final List<Conversation> convos =
      ref.watch(conversationsProvider).asData?.value ?? const <Conversation>[];
  return convos.fold<int>(0, (int sum, Conversation c) => sum + c.unreadCount);
});

/// A live chat socket, tied to the current auth token. Null until signed in.
final Provider<ChatSocket?> chatSocketProvider = Provider<ChatSocket?>((ref) {
  final String? token =
      ref.watch(authControllerProvider).asData?.value.token;
  if (token == null) {
    return null;
  }
  // http -> ws, https -> wss.
  final String base = AppConfig.apiBaseUrl.replaceFirst('http', 'ws');
  final ChatSocket socket = ChatSocket('$base/api/v1/chat/ws?token=$token');
  socket.connect();
  ref.onDispose(socket.dispose);
  return socket;
});

/// Decoded real-time chat events from the socket.
final StreamProvider<Map<String, dynamic>> chatEventsProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final ChatSocket? socket = ref.watch(chatSocketProvider);
  if (socket == null) {
    return const Stream<Map<String, dynamic>>.empty();
  }
  return socket.events;
});

/// The set of currently-online user ids, seeded from the backend and kept in
/// sync by `presence` socket events.
final AsyncNotifierProvider<PresenceNotifier, Set<int>> presenceProvider =
    AsyncNotifierProvider<PresenceNotifier, Set<int>>(PresenceNotifier.new);

class PresenceNotifier extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() async {
    ref.listen<AsyncValue<Map<String, dynamic>>>(chatEventsProvider,
        (AsyncValue<Map<String, dynamic>>? _,
            AsyncValue<Map<String, dynamic>> next) {
      next.whenData((Map<String, dynamic> e) {
        if (e['type'] != 'presence') {
          return;
        }
        final int id = e['user_id'] as int;
        final bool online = e['online'] as bool? ?? false;
        final Set<int> current = <int>{...?state.asData?.value};
        if (online) {
          current.add(id);
        } else {
          current.remove(id);
        }
        state = AsyncData<Set<int>>(current);
      });
    });
    return ref.read(chatRepositoryProvider).presence();
  }
}
