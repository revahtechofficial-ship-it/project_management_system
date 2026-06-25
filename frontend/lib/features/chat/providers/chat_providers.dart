import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../data/models/chat_member.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/link_preview.dart';
import '../../../data/models/public_channel.dart';
import '../../../data/models/user_presence.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/giphy_repository.dart';
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

/// Public channels the current user can discover and join. Invalidate to
/// refresh (e.g. after joining one).
final FutureProvider<List<PublicChannel>> publicChannelsProvider =
    FutureProvider<List<PublicChannel>>((ref) {
      return ref.watch(chatRepositoryProvider).publicChannels();
    });

/// The members (with roles) of a conversation. Invalidate to refresh after a
/// membership change.
final conversationMembersProvider =
    FutureProvider.family<List<ChatMember>, int>((ref, int conversationId) {
      return ref.watch(chatRepositoryProvider).members(conversationId);
    });

/// Total unread messages across all conversations (for the nav badge).
final Provider<int> chatUnreadProvider = Provider<int>((ref) {
  final List<Conversation> convos =
      ref.watch(conversationsProvider).asData?.value ?? const <Conversation>[];
  return convos.fold<int>(0, (int sum, Conversation c) => sum + c.unreadCount);
});

/// A live chat socket, tied to the current auth token. Null until signed in.
final Provider<ChatSocket?> chatSocketProvider = Provider<ChatSocket?>((ref) {
  final String? token = ref.watch(authControllerProvider).asData?.value.token;
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

/// The Giphy repository (GIFs + stickers).
final Provider<GiphyRepository> giphyRepositoryProvider =
    Provider<GiphyRepository>((ref) => GiphyRepository());

/// An Open Graph preview for a URL (cached per URL). Null when unavailable.
final linkPreviewProvider = FutureProvider.family<LinkPreview?, String>((
  ref,
  String url,
) {
  return ref.watch(chatRepositoryProvider).linkPreview(url);
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

/// Per-user presence/status, keyed by user id. Seeded from the backend and kept
/// in sync by `status` socket events.
final AsyncNotifierProvider<PresenceNotifier, Map<int, UserPresence>>
presenceProvider =
    AsyncNotifierProvider<PresenceNotifier, Map<int, UserPresence>>(
      PresenceNotifier.new,
    );

class PresenceNotifier extends AsyncNotifier<Map<int, UserPresence>> {
  @override
  Future<Map<int, UserPresence>> build() async {
    ref.listen<AsyncValue<Map<String, dynamic>>>(chatEventsProvider, (
      AsyncValue<Map<String, dynamic>>? _,
      AsyncValue<Map<String, dynamic>> next,
    ) {
      next.whenData((Map<String, dynamic> e) {
        if (e['type'] != 'status') {
          return;
        }
        final UserPresence p = UserPresence.fromJson(e);
        final Map<int, UserPresence> current = <int, UserPresence>{
          ...?state.asData?.value,
        };
        current[p.userId] = p;
        state = AsyncData<Map<int, UserPresence>>(current);
      });
    });
    final List<UserPresence> list = await ref
        .read(chatRepositoryProvider)
        .presence();
    return <int, UserPresence>{for (final UserPresence p in list) p.userId: p};
  }
}
