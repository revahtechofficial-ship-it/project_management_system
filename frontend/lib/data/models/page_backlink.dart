import '../enums/page_type.dart';

/// A page that links to another page via a `[[wiki link]]`, from
/// `/api/v1/pages/{id}/backlinks`. Manual JSON serialization per AGENTS.md §9.
class PageBacklink {
  final int id;
  final String title;
  final PageType type;
  final String icon;

  const PageBacklink({
    required this.id,
    this.title = '',
    this.type = PageType.doc,
    this.icon = '',
  });

  factory PageBacklink.fromJson(Map<String, dynamic> json) => PageBacklink(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    type: PageType.fromJson(json['type'] as String? ?? 'doc'),
    icon: json['icon'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'type': type.toJson(),
    'icon': icon,
  };

  @override
  String toString() => 'PageBacklink(id: $id, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageBacklink &&
          other.id == id &&
          other.title == title &&
          other.type == type &&
          other.icon == icon;

  @override
  int get hashCode => Object.hash(id, title, type, icon);
}
