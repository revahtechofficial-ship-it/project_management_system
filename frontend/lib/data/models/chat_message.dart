/// A single chat message, from the chat message endpoints. Manual JSON per
/// AGENTS.md §9.
class ChatMessage {
  final int id;
  final int conversationId;
  final int? senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final String kind;
  final String body;
  final bool edited;
  final bool pinned;
  final bool forwarded;
  final int? replyToId;
  final String? replyBody;
  final String? replyKind;
  final String? replySenderName;
  final String attachmentName;
  final String attachmentType;
  final int attachmentSize;
  final int replyCount;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.createdAt,
    this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    this.kind = 'text',
    this.body = '',
    this.edited = false,
    this.pinned = false,
    this.forwarded = false,
    this.replyToId,
    this.replyBody,
    this.replyKind,
    this.replySenderName,
    this.attachmentName = '',
    this.attachmentType = '',
    this.attachmentSize = 0,
    this.replyCount = 0,
  });

  bool get isReply => replyToId != null;

  /// Whether this message has a thread (one or more replies).
  bool get hasThread => replyCount > 0;

  /// A one-line preview for a message of [kind] with [body].
  static String previewFor(String? kind, String? body) => switch (kind) {
    'image' => '📷 Photo',
    'file' => '📎 Attachment',
    _ => body ?? '',
  };

  ChatMessage copyWith({bool? pinned, int? replyCount}) => ChatMessage(
    id: id,
    conversationId: conversationId,
    createdAt: createdAt,
    senderId: senderId,
    senderName: senderName,
    senderAvatarUrl: senderAvatarUrl,
    kind: kind,
    body: body,
    edited: edited,
    pinned: pinned ?? this.pinned,
    forwarded: forwarded,
    replyToId: replyToId,
    replyBody: replyBody,
    replyKind: replyKind,
    replySenderName: replySenderName,
    attachmentName: attachmentName,
    attachmentType: attachmentType,
    attachmentSize: attachmentSize,
    replyCount: replyCount ?? this.replyCount,
  );

  bool get isImage => kind == 'image';
  bool get hasAttachment => attachmentName.isNotEmpty;

  /// Whether this attachment is audio (a voice message or audio file).
  bool get isAudio {
    if (attachmentType.toLowerCase().startsWith('audio/')) {
      return true;
    }
    final String n = attachmentName.toLowerCase();
    return n.endsWith('.mp3') ||
        n.endsWith('.m4a') ||
        n.endsWith('.aac') ||
        n.endsWith('.ogg') ||
        n.endsWith('.oga') ||
        n.endsWith('.opus') ||
        n.endsWith('.wav') ||
        n.endsWith('.flac');
  }

  /// Whether this attachment is a video (by content type or file extension).
  bool get isVideo {
    if (attachmentType.toLowerCase().startsWith('video/')) {
      return true;
    }
    if (isAudio) {
      return false;
    }
    final String n = attachmentName.toLowerCase();
    return n.endsWith('.mp4') ||
        n.endsWith('.webm') ||
        n.endsWith('.mov') ||
        n.endsWith('.mkv') ||
        n.endsWith('.avi') ||
        n.endsWith('.m4v');
  }

  /// A human-readable attachment size, e.g. `1.2 MB`.
  String get sizeLabel {
    if (attachmentSize < 1024) {
      return '$attachmentSize B';
    }
    if (attachmentSize < 1024 * 1024) {
      return '${(attachmentSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(attachmentSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    conversationId: json['conversation_id'] as int,
    senderId: json['sender_id'] as int?,
    senderName: json['sender_name'] as String?,
    senderAvatarUrl: json['sender_avatar_url'] as String?,
    kind: json['kind'] as String? ?? 'text',
    body: json['body'] as String? ?? '',
    edited: json['edited'] as bool? ?? false,
    pinned: json['pinned'] as bool? ?? false,
    forwarded: json['forwarded'] as bool? ?? false,
    replyToId: json['reply_to_id'] as int?,
    replyBody: json['reply_body'] as String?,
    replyKind: json['reply_kind'] as String?,
    replySenderName: json['reply_sender_name'] as String?,
    attachmentName: json['attachment_name'] as String? ?? '',
    attachmentType: json['attachment_type'] as String? ?? '',
    attachmentSize: json['attachment_size'] as int? ?? 0,
    replyCount: json['reply_count'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    'sender_name': senderName,
    'sender_avatar_url': senderAvatarUrl,
    'kind': kind,
    'body': body,
    'edited': edited,
    'pinned': pinned,
    'forwarded': forwarded,
    'reply_to_id': replyToId,
    'reply_body': replyBody,
    'reply_kind': replyKind,
    'reply_sender_name': replySenderName,
    'attachment_name': attachmentName,
    'attachment_type': attachmentType,
    'attachment_size': attachmentSize,
    'reply_count': replyCount,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() => 'ChatMessage(id: $id, kind: $kind)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatMessage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
