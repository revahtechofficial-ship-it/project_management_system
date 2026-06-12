import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/constants/app_config.dart';
import '../models/call_credentials.dart';
import '../models/chat_member.dart';
import '../models/chat_message.dart';
import '../models/chat_reaction.dart';
import '../models/conversation.dart';

/// Talks to the backend's /api/v1/chat endpoints (AGENTS.md §1
/// `data/repositories`).
class ChatRepository {
  const ChatRepository(this._dio);

  final Dio _dio;

  /// The current user's conversations, most-recent first.
  Future<List<Conversation>> conversations() async {
    final Response<List<dynamic>> res = await _dio
        .get<List<dynamic>>('/api/v1/chat/conversations');
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Finds or creates a 1:1 conversation with [userId]; returns its id.
  Future<int> createDm(int userId) async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      '/api/v1/chat/conversations',
      data: <String, dynamic>{'type': 'dm', 'member_ids': <int>[userId]},
    );
    return (res.data ?? const <String, dynamic>{})['id'] as int;
  }

  /// Creates a group conversation; returns its id.
  Future<int> createGroup(String name, List<int> memberIds) async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      '/api/v1/chat/conversations',
      data: <String, dynamic>{
        'type': 'group',
        'name': name,
        'member_ids': memberIds,
      },
    );
    return (res.data ?? const <String, dynamic>{})['id'] as int;
  }

  /// Messages in a conversation, newest first (server order).
  Future<List<ChatMessage>> messages(
    int conversationId, {
    int limit = 30,
    int offset = 0,
  }) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/chat/conversations/$conversationId/messages',
      queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Sends a text message and returns the stored message.
  Future<ChatMessage> sendText(int conversationId, String body) async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      '/api/v1/chat/conversations/$conversationId/messages',
      data: <String, dynamic>{'body': body},
    );
    return ChatMessage.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Uploads a file/image as a message and returns the stored message.
  Future<ChatMessage> uploadFile(
    int conversationId,
    Uint8List bytes,
    String filename, {
    String caption = '',
  }) async {
    final FormData form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      'caption': caption,
    });
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      '/api/v1/chat/conversations/$conversationId/upload',
      data: form,
    );
    return ChatMessage.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Marks the conversation read up to now for the current user.
  Future<void> markRead(int conversationId) =>
      _dio.post<void>('/api/v1/chat/conversations/$conversationId/read');

  /// Lists the members of a conversation.
  Future<List<ChatMember>> members(int conversationId) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
        '/api/v1/chat/conversations/$conversationId/members');
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => ChatMember.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Adds members to a group conversation.
  Future<void> addMembers(int conversationId, List<int> userIds) =>
      _dio.post<void>(
        '/api/v1/chat/conversations/$conversationId/members',
        data: <String, dynamic>{'user_ids': userIds},
      );

  /// Removes a member (self-leave, or admin removing another).
  Future<void> removeMember(int conversationId, int userId) => _dio.delete<void>(
      '/api/v1/chat/conversations/$conversationId/members/$userId');

  /// Renames a group conversation.
  Future<void> rename(int conversationId, String name) =>
      _dio.patch<void>(
        '/api/v1/chat/conversations/$conversationId',
        data: <String, dynamic>{'name': name},
      );

  /// Deletes a message (its sender, or a conversation admin).
  Future<void> deleteMessage(int messageId) =>
      _dio.delete<void>('/api/v1/chat/messages/$messageId');

  /// Edits a text message's body (sender only).
  Future<ChatMessage> editMessage(int messageId, String body) async {
    final Response<Map<String, dynamic>> res =
        await _dio.patch<Map<String, dynamic>>(
      '/api/v1/chat/messages/$messageId',
      data: <String, dynamic>{'body': body},
    );
    return ChatMessage.fromJson(res.data ?? const <String, dynamic>{});
  }

  /// Toggles the current user's [emoji] reaction on a message.
  Future<void> toggleReaction(int messageId, String emoji) =>
      _dio.post<void>(
        '/api/v1/chat/messages/$messageId/reactions',
        data: <String, dynamic>{'emoji': emoji},
      );

  /// All reactions on a conversation's messages.
  Future<List<ChatReaction>> reactions(int conversationId) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
        '/api/v1/chat/conversations/$conversationId/reactions');
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => ChatReaction.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// The ids of users currently connected to the chat socket.
  Future<Set<int>> presence() async {
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>('/api/v1/chat/presence');
    final List<dynamic> online =
        (res.data ?? const <String, dynamic>{})['online'] as List<dynamic>? ??
            <dynamic>[];
    return online.map((dynamic e) => e as int).toSet();
  }

  /// The authenticated URL to download/preview a message attachment.
  String attachmentUrl(int messageId, String token) =>
      '${AppConfig.apiBaseUrl}/api/v1/chat/messages/$messageId/download'
      '?token=$token';

  /// Requests a LiveKit join token for a conversation's call. Set [ring] true
  /// when starting a call to ring the other members.
  Future<CallCredentials> requestCall(
    int conversationId, {
    required String mode,
    required bool ring,
  }) async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      '/api/v1/chat/conversations/$conversationId/call-token',
      data: <String, dynamic>{'mode': mode, 'ring': ring},
    );
    return CallCredentials.fromJson(res.data ?? const <String, dynamic>{});
  }
}
