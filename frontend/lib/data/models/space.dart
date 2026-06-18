import 'package:flutter/material.dart';

/// A top-level container in the project hierarchy (Space › Folder › Project).
/// Manual JSON serialization per AGENTS.md §9.
class Space {
  final int id;
  final String name;
  final String colorHex;
  final int position;

  const Space({
    required this.id,
    this.name = '',
    this.colorHex = '#6366f1',
    this.position = 0,
  });

  /// The parsed accent color (falls back to indigo on a malformed hex).
  Color get color {
    final String h = colorHex.replaceFirst('#', '');
    final int? v = int.tryParse(h, radix: 16);
    if (v == null || h.length != 6) {
      return const Color(0xFF6366F1);
    }
    return Color(0xFF000000 | v);
  }

  factory Space.fromJson(Map<String, dynamic> json) => Space(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    colorHex: json['color'] as String? ?? '#6366f1',
    position: json['position'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'color': colorHex,
    'position': position,
  };

  @override
  String toString() => 'Space(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Space &&
          other.id == id &&
          other.name == name &&
          other.colorHex == colorHex &&
          other.position == position;

  @override
  int get hashCode => Object.hash(id, name, colorHex, position);
}
