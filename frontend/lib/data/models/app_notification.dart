/// A workspace notification from `GET /api/v1/notifications`. Manual JSON
/// serialization per AGENTS.md §9.
class AppNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  final String link;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.read,
    required this.createdAt,
    this.type = '',
    this.title = '',
    this.body = '',
    this.link = '',
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        link: json['link'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'link': link,
    'read': read,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String toString() =>
      'AppNotification(id: $id, type: $type, title: $title, read: $read)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          other.id == id &&
          other.type == type &&
          other.title == title &&
          other.body == body &&
          other.link == link &&
          other.read == read &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, type, title, body, link, read, createdAt);
}
