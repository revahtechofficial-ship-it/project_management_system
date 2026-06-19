/// A saved, shareable dashboard from `GET /api/v1/dashboards`. Manual JSON
/// serialization per AGENTS.md §9.
class SavedDashboard {
  final int id;
  final String name;
  final int? ownerId;
  final String ownerName;
  final String visibility;
  final List<String> widgets;
  final bool canManage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedDashboard({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.name = '',
    this.ownerId,
    this.ownerName = '',
    this.visibility = 'workspace',
    this.widgets = const <String>[],
    this.canManage = false,
  });

  bool get isPrivate => visibility == 'private';

  factory SavedDashboard.fromJson(Map<String, dynamic> json) => SavedDashboard(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    ownerId: json['owner_id'] as int?,
    ownerName: json['owner_name'] as String? ?? '',
    visibility: json['visibility'] as String? ?? 'workspace',
    widgets: (json['widgets'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => e as String)
        .toList(growable: false),
    canManage: json['can_manage'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'owner_id': ownerId,
    'owner_name': ownerName,
    'visibility': visibility,
    'widgets': widgets,
    'can_manage': canManage,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  @override
  String toString() => 'SavedDashboard(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedDashboard &&
          other.id == id &&
          other.name == name &&
          other.ownerId == ownerId &&
          other.ownerName == ownerName &&
          other.visibility == visibility &&
          _listEq(other.widgets, widgets) &&
          other.canManage == canManage &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    ownerId,
    ownerName,
    visibility,
    Object.hashAll(widgets),
    canManage,
    createdAt,
    updatedAt,
  );

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
