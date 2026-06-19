/// The input types a form field can use. Tied to the [FormField] model, so it
/// carries `toJson`/`fromJson` with a sentinel default (AGENTS.md §9).
enum FormFieldType {
  text,
  textarea,
  number,
  select,
  checkbox,
  unknown;

  String get label => switch (this) {
    FormFieldType.text => 'Short text',
    FormFieldType.textarea => 'Long text',
    FormFieldType.number => 'Number',
    FormFieldType.select => 'Dropdown',
    FormFieldType.checkbox => 'Checkbox',
    FormFieldType.unknown => 'Text',
  };

  /// Whether this type uses the [FormField.options] list.
  bool get hasOptions => this == FormFieldType.select;

  String toJson() => switch (this) {
    FormFieldType.text => 'text',
    FormFieldType.textarea => 'textarea',
    FormFieldType.number => 'number',
    FormFieldType.select => 'select',
    FormFieldType.checkbox => 'checkbox',
    FormFieldType.unknown => '',
  };

  factory FormFieldType.fromJson(String value) => switch (value) {
    'text' => FormFieldType.text,
    'textarea' => FormFieldType.textarea,
    'number' => FormFieldType.number,
    'select' => FormFieldType.select,
    'checkbox' => FormFieldType.checkbox,
    _ => FormFieldType.unknown,
  };

  /// The types offered in the builder (excludes the sentinel).
  static List<FormFieldType> get selectable => <FormFieldType>[
    FormFieldType.text,
    FormFieldType.textarea,
    FormFieldType.number,
    FormFieldType.select,
    FormFieldType.checkbox,
  ];
}
