/// A named, saved task filter, from `GET /api/v1/saved-filters`. The [config]
/// holds the filter criteria. Manual JSON serialization per AGENTS.md §9.
class SavedFilter {
  final int id;
  final String name;
  final Map<String, dynamic> config;

  const SavedFilter({
    required this.id,
    this.name = '',
    this.config = const <String, dynamic>{},
  });

  factory SavedFilter.fromJson(Map<String, dynamic> json) => SavedFilter(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    config:
        (json['config'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'config': config,
  };

  @override
  String toString() => 'SavedFilter(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedFilter && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
