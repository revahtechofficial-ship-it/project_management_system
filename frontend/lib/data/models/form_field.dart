import '../enums/form_field_type.dart';

/// A single field in a form definition, stored (as a list) in the page body.
/// Manual JSON serialization per AGENTS.md §9.
class FormField {
  final String id;
  final String label;
  final FormFieldType type;
  final bool required;
  final List<String> options;

  const FormField({
    required this.id,
    required this.required,
    this.label = '',
    this.type = FormFieldType.text,
    this.options = const <String>[],
  });

  FormField copyWith({
    String? label,
    FormFieldType? type,
    bool? required,
    List<String>? options,
  }) => FormField(
    id: id,
    label: label ?? this.label,
    type: type ?? this.type,
    required: required ?? this.required,
    options: options ?? this.options,
  );

  factory FormField.fromJson(Map<String, dynamic> json) => FormField(
    id: json['id'] as String? ?? '',
    label: json['label'] as String? ?? '',
    type: FormFieldType.fromJson(json['type'] as String? ?? ''),
    required: json['required'] as bool? ?? false,
    options: (json['options'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => e as String)
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'type': type.toJson(),
    'required': required,
    'options': options,
  };

  @override
  String toString() => 'FormField(id: $id, label: $label, type: $type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormField &&
          other.id == id &&
          other.label == label &&
          other.type == type &&
          other.required == required &&
          _eq(other.options, options);

  @override
  int get hashCode =>
      Object.hash(id, label, type, required, Object.hashAll(options));

  static bool _eq(List<String> a, List<String> b) {
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
