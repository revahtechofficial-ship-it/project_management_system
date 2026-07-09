import '../enums/user_status.dart';

/// A user's live presence: whether they're connected, their chosen status,
/// optional custom message, and when they were last seen. From
/// `GET /api/v1/chat/presence` and `status` socket events. Manual JSON per
/// AGENTS.md §9.
class UserPresence {
  final int userId;
  final bool online;
  final UserStatus status;
  final String statusMessage;
  final DateTime? lastSeen;

  const UserPresence({
    required this.userId,
    this.online = false,
    this.status = UserStatus.active,
    this.statusMessage = '',
    this.lastSeen,
  });

  /// The status to display: offline when not connected, otherwise the chosen
  /// status.
  UserStatus get effective => online ? status : UserStatus.offline;

  factory UserPresence.fromJson(Map<String, dynamic> json) => UserPresence(
    userId: json['user_id'] as int,
    online: json['online'] as bool? ?? false,
    status: UserStatus.fromJson(json['status'] as String? ?? 'active'),
    statusMessage: json['status_message'] as String? ?? '',
    lastSeen: json['last_seen_at'] == null
        ? null
        : DateTime.tryParse(json['last_seen_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'online': online,
    'status': status.toJson(),
    'status_message': statusMessage,
    'last_seen_at': lastSeen?.toIso8601String(),
  };

  @override
  String toString() => 'UserPresence($userId, ${effective.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPresence &&
          other.userId == userId &&
          other.online == online &&
          other.status == status &&
          other.statusMessage == statusMessage &&
          other.lastSeen == lastSeen;

  @override
  int get hashCode =>
      Object.hash(userId, online, status, statusMessage, lastSeen);
}
