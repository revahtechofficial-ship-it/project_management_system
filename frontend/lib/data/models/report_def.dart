/// One filter in a saved report: a field, an operator (is / is_not / contains)
/// and a comparison value.
class ReportFilter {
  final String field;
  final String op;
  final String value;

  const ReportFilter({this.field = 'status', this.op = 'is', this.value = ''});

  ReportFilter copyWith({String? field, String? op, String? value}) =>
      ReportFilter(
        field: field ?? this.field,
        op: op ?? this.op,
        value: value ?? this.value,
      );

  factory ReportFilter.fromJson(Map<String, dynamic> json) => ReportFilter(
        field: json['field'] as String? ?? 'status',
        op: json['op'] as String? ?? 'is',
        value: json['value'] as String? ?? '',
      );

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'field': field, 'op': op, 'value': value};

  @override
  String toString() => 'ReportFilter($field $op $value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportFilter &&
          other.field == field &&
          other.op == op &&
          other.value == value;

  @override
  int get hashCode => Object.hash(field, op, value);
}

/// A saved custom report definition over tasks: which columns to show and how
/// to filter, from `/api/v1/reports`. Manual JSON serialization per AGENTS.md
/// §9. The `columns` + `filters` live under a nested `config` object.
class ReportDef {
  final int id;
  final String name;
  final List<String> columns;
  final List<ReportFilter> filters;
  final DateTime createdAt;

  const ReportDef({
    required this.id,
    required this.createdAt,
    this.name = '',
    this.columns = const <String>[],
    this.filters = const <ReportFilter>[],
  });

  /// The `config` object sent to / stored on the server.
  Map<String, dynamic> get config => <String, dynamic>{
        'columns': columns,
        'filters': filters.map((ReportFilter f) => f.toJson()).toList(),
      };

  factory ReportDef.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> cfg =
        json['config'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return ReportDef(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      columns: <String>[
        for (final dynamic e in (cfg['columns'] as List<dynamic>? ??
            <dynamic>[]))
          e as String,
      ],
      filters: <ReportFilter>[
        for (final dynamic e
            in (cfg['filters'] as List<dynamic>? ?? <dynamic>[]))
          ReportFilter.fromJson(e as Map<String, dynamic>),
      ],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'config': config,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String toString() => 'ReportDef(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportDef &&
          other.id == id &&
          other.name == name &&
          _eq(other.columns, columns) &&
          _eq(other.filters, filters) &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        Object.hashAll(columns),
        Object.hashAll(filters),
        createdAt,
      );

  static bool _eq(List<Object?> a, List<Object?> b) {
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
