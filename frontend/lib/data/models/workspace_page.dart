import '../enums/page_type.dart';

/// A collaborative workspace page — a Doc, Whiteboard or Form — from
/// `GET /api/v1/pages`. Manual JSON serialization per AGENTS.md §9.
class WorkspacePage {
  final int id;
  final PageType type;
  final String title;
  final String icon;
  final String body;
  final int? parentId;
  final bool isTemplate;
  final String category;
  final int? ownerId;
  final String ownerName;
  final DateTime? reviewAt;
  final String visibility;
  final String access;
  final bool canManage;
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
    this.parentId,
    this.isTemplate = false,
    this.category = '',
    this.ownerId,
    this.ownerName = '',
    this.reviewAt,
    this.visibility = 'workspace',
    this.access = 'edit',
    this.canManage = false,
    this.createdByName = '',
    this.updatedByName = '',
  });

  /// A non-empty title for display.
  String get displayTitle => title.trim().isEmpty ? 'Untitled' : title;

  /// Whether the current user may edit this page (vs. view-only).
  bool get canEdit => access == 'edit';

  /// Whether the page is restricted to its author and shared users.
  bool get isPrivate => visibility == 'private';

  /// Whether this SOP's review date has passed (so it needs a refresh).
  bool get needsReview =>
      reviewAt != null && reviewAt!.toLocal().isBefore(DateTime.now());

  factory WorkspacePage.fromJson(Map<String, dynamic> json) => WorkspacePage(
    id: json['id'] as int,
    type: PageType.fromJson(json['type'] as String? ?? 'doc'),
    title: json['title'] as String? ?? '',
    icon: json['icon'] as String? ?? '',
    body: json['body'] as String? ?? '',
    parentId: json['parent_id'] as int?,
    isTemplate: json['is_template'] as bool? ?? false,
    category: json['category'] as String? ?? '',
    ownerId: json['owner_id'] as int?,
    ownerName: json['owner_name'] as String? ?? '',
    reviewAt: json['review_at'] == null
        ? null
        : DateTime.parse(json['review_at'] as String),
    visibility: json['visibility'] as String? ?? 'workspace',
    access: json['access'] as String? ?? 'edit',
    canManage: json['can_manage'] as bool? ?? false,
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
    'parent_id': parentId,
    'is_template': isTemplate,
    'category': category,
    'owner_id': ownerId,
    'owner_name': ownerName,
    'review_at': reviewAt?.toIso8601String(),
    'visibility': visibility,
    'access': access,
    'can_manage': canManage,
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
          other.parentId == parentId &&
          other.isTemplate == isTemplate &&
          other.category == category &&
          other.ownerId == ownerId &&
          other.ownerName == ownerName &&
          other.reviewAt == reviewAt &&
          other.visibility == visibility &&
          other.access == access &&
          other.canManage == canManage &&
          other.createdByName == createdByName &&
          other.updatedByName == updatedByName &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    type,
    title,
    icon,
    body,
    parentId,
    isTemplate,
    category,
    ownerId,
    ownerName,
    reviewAt,
    visibility,
    access,
    canManage,
    createdByName,
    updatedByName,
    createdAt,
    updatedAt,
  ]);
}
