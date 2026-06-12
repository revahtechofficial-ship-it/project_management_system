/// A chat conversation (direct or group) for the current user, from
/// `GET /api/v1/chat/conversations`. Manual JSON per AGENTS.md §9.
class Conversation {
  final int id;
  final String type;
  final String name;
  final int? otherUserId;
  final int unreadCount;
  final String lastBody;
  final String lastKind;
  final DateTime lastAt;
  final int? lastSenderId;
  final DateTime createdAt;

  const Conversation({
    required this.id,
    required this.lastAt,
    required this.createdAt,
    this.type = 'dm',
    this.name = '',
    this.otherUserId,
    this.unreadCount = 0,
    this.lastBody = '',
    this.lastKind = '',
    this.lastSenderId,
  });

  bool get isGroup => type == 'group';

  /// A one-line preview of the most recent message.
  String get preview => switch (lastKind) {
        'image' => '📷 Photo',
        'file' => '📎 Attachment',
        _ => lastBody,
      };

  Conversation copyWith({int? unreadCount}) => Conversation(
        id: id,
        lastAt: lastAt,
        createdAt: createdAt,
        type: type,
        name: name,
        otherUserId: otherUserId,
        unreadCount: unreadCount ?? this.unreadCount,
        lastBody: lastBody,
        lastKind: lastKind,
        lastSenderId: lastSenderId,
      );

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as int,
        type: json['type'] as String? ?? 'dm',
        name: json['name'] as String? ?? '',
        otherUserId: json['other_user_id'] as int?,
        unreadCount: json['unread_count'] as int? ?? 0,
        lastBody: json['last_body'] as String? ?? '',
        lastKind: json['last_kind'] as String? ?? '',
        lastAt: DateTime.parse(json['last_at'] as String),
        lastSenderId: json['last_sender_id'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'name': name,
        'other_user_id': otherUserId,
        'unread_count': unreadCount,
        'last_body': lastBody,
        'last_kind': lastKind,
        'last_at': lastAt.toIso8601String(),
        'last_sender_id': lastSenderId,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'Conversation(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          other.id == id &&
          other.type == type &&
          other.name == name &&
          other.otherUserId == otherUserId &&
          other.unreadCount == unreadCount &&
          other.lastBody == lastBody &&
          other.lastKind == lastKind &&
          other.lastAt == lastAt &&
          other.lastSenderId == lastSenderId &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, type, name, otherUserId, unreadCount,
      lastBody, lastKind, lastAt, lastSenderId, createdAt);
}
