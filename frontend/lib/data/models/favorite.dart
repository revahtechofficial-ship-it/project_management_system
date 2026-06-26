/// A user's favorited item (a task, project or page) for quick access, from
/// `GET /api/v1/favorites`. Manual JSON serialization per AGENTS.md §9.
class Favorite {
  final int id;
  final String kind;
  final int itemId;
  final String label;
  final String route;

  const Favorite({
    required this.id,
    required this.itemId,
    this.kind = '',
    this.label = '',
    this.route = '',
  });

  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
    id: json['id'] as int,
    kind: json['kind'] as String? ?? '',
    itemId: (json['item_id'] as num).toInt(),
    label: json['label'] as String? ?? '',
    route: json['route'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind,
    'item_id': itemId,
    'label': label,
    'route': route,
  };

  @override
  String toString() => 'Favorite($kind:$itemId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Favorite &&
          other.id == id &&
          other.kind == kind &&
          other.itemId == itemId &&
          other.label == label &&
          other.route == route;

  @override
  int get hashCode => Object.hash(id, kind, itemId, label, route);
}
