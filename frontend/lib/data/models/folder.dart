/// A folder inside a [Space] that groups projects. Manual JSON serialization
/// per AGENTS.md §9.
class Folder {
  final int id;
  final int spaceId;
  final String name;
  final int position;

  const Folder({
    required this.id,
    required this.spaceId,
    this.name = '',
    this.position = 0,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
    id: json['id'] as int,
    spaceId: (json['space_id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    position: json['position'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'space_id': spaceId,
    'name': name,
    'position': position,
  };

  @override
  String toString() => 'Folder(id: $id, name: $name, spaceId: $spaceId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Folder &&
          other.id == id &&
          other.spaceId == spaceId &&
          other.name == name &&
          other.position == position;

  @override
  int get hashCode => Object.hash(id, spaceId, name, position);
}
