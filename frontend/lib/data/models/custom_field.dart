import 'package:flutter/foundation.dart';

import '../enums/custom_field_type.dart';

/// A workspace-defined custom field for tasks, from `GET /api/v1/custom-fields`.
/// Manual JSON serialization per AGENTS.md §9.
class CustomField {
  final int id;
  final String name;
  final CustomFieldType type;
  final List<String> options;

  const CustomField({
    required this.id,
    this.name = '',
    this.type = CustomFieldType.text,
    this.options = const <String>[],
  });

  factory CustomField.fromJson(Map<String, dynamic> json) => CustomField(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    type: CustomFieldType.fromJson(json['type'] as String? ?? 'text'),
    options: (json['options'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => e as String)
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'type': type.toJson(),
    'options': options,
  };

  @override
  String toString() => 'CustomField(id: $id, name: $name, type: $type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomField &&
          other.id == id &&
          other.name == name &&
          other.type == type &&
          listEquals(other.options, options);

  @override
  int get hashCode => Object.hash(id, name, type, Object.hashAll(options));
}
