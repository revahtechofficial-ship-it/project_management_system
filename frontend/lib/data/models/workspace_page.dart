import '../enums/page_type.dart';

/// A collaborative workspace page — a Doc, Whiteboard or Form — from
/// `GET /api/v1/pages`. Manual JSON serialization per AGENTS.md §9.
class WorkspacePage {
  final int id;
  final PageType type;
  final String title;
  final String icon;
  final String body;
  final String createdByName;
  final String updatedByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkspacePage({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.type = PageType.doc,
    this.title = '',
    this.icon = '',
    this.body = '',
    this.createdByName = '',
    this.updatedByName = '',
  });

  /// A non-empty title for display.
  String get displayTitle => title.trim().isEmpty ? 'Untitled' : title;

  factory WorkspacePage.fromJson(Map<String, dynamic> json) => WorkspacePage(
    id: json['id'] as int,
    type: PageType.fromJson(json['type'] as String? ?? 'doc'),
    title: json['title'] as String? ?? '',
    icon: json['icon'] as String? ?? '',
    body: json['body'] as String? ?? '',
    createdByName: json['created_by_name'] as String? ?? '',
    updatedByName: json['updated_by_name'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type.toJson(),
    'title': title,
    'icon': icon,
    'body': body,
    'created_by_name': createdByName,
    'updated_by_name': updatedByName,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  @override
  String toString() => 'WorkspacePage(id: $id, type: $type, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspacePage &&
          other.id == id &&
          other.type == type &&
          other.title == title &&
          other.icon == icon &&
          other.body == body &&
          other.createdByName == createdByName &&
          other.updatedByName == updatedByName &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    title,
    icon,
    body,
    createdByName,
    updatedByName,
    createdAt,
    updatedAt,
  );
}
