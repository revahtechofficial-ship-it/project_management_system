/// A single unread notification in the digest.
class DigestNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  final String link;
  final DateTime createdAt;

  const DigestNotification({
    required this.id,
    required this.createdAt,
    this.type = '',
    this.title = '',
    this.body = '',
    this.link = '',
  });

  factory DigestNotification.fromJson(Map<String, dynamic> json) =>
      DigestNotification(
        id: json['id'] as int,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        link: json['link'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'link': link,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'DigestNotification(id: $id, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DigestNotification &&
          other.id == id &&
          other.type == type &&
          other.title == title &&
          other.body == body &&
          other.link == link &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, type, title, body, link, createdAt);
}

/// A task in the digest — either overdue or due within the week.
class DigestTask {
  final int id;
  final String title;
  final String status;
  final DateTime dueDate;

  const DigestTask({
    required this.id,
    required this.dueDate,
    this.title = '',
    this.status = '',
  });

  factory DigestTask.fromJson(Map<String, dynamic> json) => DigestTask(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        status: json['status'] as String? ?? '',
        dueDate: DateTime.parse(json['due_date'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'status': status,
        'due_date': dueDate.toIso8601String(),
      };

  @override
  String toString() => 'DigestTask(id: $id, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DigestTask &&
          other.id == id &&
          other.title == title &&
          other.status == status &&
          other.dueDate == dueDate;

  @override
  int get hashCode => Object.hash(id, title, status, dueDate);
}

/// A personal summary of unread notifications and tasks due soon or overdue,
/// from `/api/v1/digest`. Manual JSON serialization per AGENTS.md §9.
class DigestData {
  final int unreadCount;
  final List<DigestNotification> notifications;
  final List<DigestTask> overdue;
  final List<DigestTask> upcoming;

  const DigestData({
    this.unreadCount = 0,
    this.notifications = const <DigestNotification>[],
    this.overdue = const <DigestTask>[],
    this.upcoming = const <DigestTask>[],
  });

  /// True when there is nothing to summarise.
  bool get isEmpty =>
      unreadCount == 0 && overdue.isEmpty && upcoming.isEmpty;

  factory DigestData.fromJson(Map<String, dynamic> json) => DigestData(
        unreadCount: json['unread_count'] as int? ?? 0,
        notifications: <DigestNotification>[
          for (final dynamic e in (json['notifications'] as List<dynamic>? ??
              <dynamic>[]))
            DigestNotification.fromJson(e as Map<String, dynamic>),
        ],
        overdue: <DigestTask>[
          for (final dynamic e
              in (json['overdue'] as List<dynamic>? ?? <dynamic>[]))
            DigestTask.fromJson(e as Map<String, dynamic>),
        ],
        upcoming: <DigestTask>[
          for (final dynamic e
              in (json['upcoming'] as List<dynamic>? ?? <dynamic>[]))
            DigestTask.fromJson(e as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'unread_count': unreadCount,
        'notifications':
            notifications.map((DigestNotification n) => n.toJson()).toList(),
        'overdue': overdue.map((DigestTask t) => t.toJson()).toList(),
        'upcoming': upcoming.map((DigestTask t) => t.toJson()).toList(),
      };

  @override
  String toString() =>
      'DigestData(unread: $unreadCount, overdue: ${overdue.length}, '
      'upcoming: ${upcoming.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DigestData &&
          other.unreadCount == unreadCount &&
          _eq(other.notifications, notifications) &&
          _eq(other.overdue, overdue) &&
          _eq(other.upcoming, upcoming);

  @override
  int get hashCode => Object.hash(
        unreadCount,
        Object.hashAll(notifications),
        Object.hashAll(overdue),
        Object.hashAll(upcoming),
      );

  static bool _eq(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
