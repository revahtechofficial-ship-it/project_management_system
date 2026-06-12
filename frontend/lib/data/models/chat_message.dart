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
  final String attachmentName;
  final String attachmentType;
  final int attachmentSize;
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
    this.attachmentName = '',
    this.attachmentType = '',
    this.attachmentSize = 0,
  });

  bool get isImage => kind == 'image';
  bool get hasAttachment => attachmentName.isNotEmpty;

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
        attachmentName: json['attachment_name'] as String? ?? '',
        attachmentType: json['attachment_type'] as String? ?? '',
        attachmentSize: json['attachment_size'] as int? ?? 0,
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
        'attachment_name': attachmentName,
        'attachment_type': attachmentType,
        'attachment_size': attachmentSize,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'ChatMessage(id: $id, kind: $kind)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
