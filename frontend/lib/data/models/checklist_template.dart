/// A reusable named checklist that can be applied to any task, from
/// `/api/v1/checklist-templates`. Manual JSON serialization per AGENTS.md §9.
class ChecklistTemplate {
  final int id;
  final String name;
  final String category;
  final List<String> items;
  final DateTime createdAt;

  const ChecklistTemplate({
    required this.id,
    required this.createdAt,
    this.name = '',
    this.category = '',
    this.items = const <String>[],
  });

  /// The checklist rendered as Markdown task items (`- [ ] item`).
  String get asMarkdown =>
      items.map((String i) => '- [ ] $i').join('\n');

  factory ChecklistTemplate.fromJson(Map<String, dynamic> json) =>
      ChecklistTemplate(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        items: <String>[
          for (final dynamic e in (json['items'] as List<dynamic>? ??
              <dynamic>[]))
            e as String,
        ],
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category,
        'items': items,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() =>
      'ChecklistTemplate(id: $id, name: $name, ${items.length} items)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistTemplate &&
          other.id == id &&
          other.name == name &&
          other.category == category &&
          _listEq(other.items, items) &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, name, category, Object.hashAll(items), createdAt);

  static bool _listEq(List<String> a, List<String> b) {
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
