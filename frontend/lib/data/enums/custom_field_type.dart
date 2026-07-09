import 'package:flutter/material.dart';

/// The data type of a user-defined custom field. Tied to the `CustomField`
/// model, so it carries `toJson` / `fromJson` with a sentinel (AGENTS.md §9).
enum CustomFieldType {
  text,
  number,
  date,
  select,
  checkbox,
  other;

  String get label => switch (this) {
    CustomFieldType.text => 'Text',
    CustomFieldType.number => 'Number',
    CustomFieldType.date => 'Date',
    CustomFieldType.select => 'Dropdown',
    CustomFieldType.checkbox => 'Checkbox',
    CustomFieldType.other => 'Text',
  };

  IconData get icon => switch (this) {
    CustomFieldType.text => Icons.short_text,
    CustomFieldType.number => Icons.numbers,
    CustomFieldType.date => Icons.event,
    CustomFieldType.select => Icons.arrow_drop_down_circle_outlined,
    CustomFieldType.checkbox => Icons.check_box_outlined,
    CustomFieldType.other => Icons.short_text,
  };

  /// Whether this type stores a list of choices.
  bool get hasOptions => this == CustomFieldType.select;

  String toJson() => switch (this) {
    CustomFieldType.text => 'text',
    CustomFieldType.number => 'number',
    CustomFieldType.date => 'date',
    CustomFieldType.select => 'select',
    CustomFieldType.checkbox => 'checkbox',
    CustomFieldType.other => 'text',
  };

  factory CustomFieldType.fromJson(String value) => switch (value) {
    'text' => CustomFieldType.text,
    'number' => CustomFieldType.number,
    'date' => CustomFieldType.date,
    'select' => CustomFieldType.select,
    'checkbox' => CustomFieldType.checkbox,
    _ => CustomFieldType.other,
  };

  /// The types offered when creating a field.
  static List<CustomFieldType> get selectableValue => <CustomFieldType>[
    CustomFieldType.text,
    CustomFieldType.number,
    CustomFieldType.date,
    CustomFieldType.select,
    CustomFieldType.checkbox,
  ];
}
