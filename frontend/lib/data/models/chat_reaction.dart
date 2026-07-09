/// A single emoji reaction by one user on one message, from
/// `GET /conversations/{id}/reactions`. Manual JSON per AGENTS.md §9.
class ChatReaction {
  final int messageId;
  final String emoji;
  final int userId;

  const ChatReaction({
    required this.messageId,
    required this.userId,
    this.emoji = '',
  });

  factory ChatReaction.fromJson(Map<String, dynamic> json) => ChatReaction(
    messageId: json['message_id'] as int,
    emoji: json['emoji'] as String? ?? '',
    userId: json['user_id'] as int,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'message_id': messageId,
    'emoji': emoji,
    'user_id': userId,
  };

  @override
  String toString() => 'ChatReaction($messageId, $emoji, $userId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatReaction &&
          other.messageId == messageId &&
          other.emoji == emoji &&
          other.userId == userId;

  @override
  int get hashCode => Object.hash(messageId, emoji, userId);
}
