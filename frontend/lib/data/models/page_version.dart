/// A saved revision of a page's content, from
/// `/api/v1/pages/{id}/versions`. Manual JSON serialization per AGENTS.md §9.
class PageVersion {
  final int id;
  final String title;
  final String body;
  final String editorName;
  final DateTime editedAt;
  final DateTime createdAt;

  const PageVersion({
    required this.id,
    required this.editedAt,
    required this.createdAt,
    this.title = '',
    this.body = '',
    this.editorName = '',
  });

  /// A short single-line preview of the revision's body.
  String get preview {
    final String flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length > 140 ? '${flat.substring(0, 140)}…' : flat;
  }

  factory PageVersion.fromJson(Map<String, dynamic> json) => PageVersion(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        editorName: json['editor_name'] as String? ?? '',
        editedAt: DateTime.parse(json['edited_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'editor_name': editorName,
        'edited_at': editedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'PageVersion(id: $id, $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageVersion &&
          other.id == id &&
          other.title == title &&
          other.body == body &&
          other.editorName == editorName &&
          other.editedAt == editedAt &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, title, body, editorName, editedAt, createdAt);
}
