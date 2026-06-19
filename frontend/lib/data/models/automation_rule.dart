/// A condition in an automation rule: `field op value` (e.g. `priority is high`).
class RuleCondition {
  final String field;
  final String op;
  final String value;

  const RuleCondition({this.field = 'status', this.op = 'is', this.value = ''});

  RuleCondition copyWith({String? field, String? op, String? value}) =>
      RuleCondition(
        field: field ?? this.field,
        op: op ?? this.op,
        value: value ?? this.value,
      );

  factory RuleCondition.fromJson(Map<String, dynamic> json) => RuleCondition(
    field: json['field'] as String? ?? 'status',
    op: json['op'] as String? ?? 'is',
    value: json['value'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'field': field,
    'op': op,
    'value': value,
  };
}

/// An action an automation rule performs (e.g. `set_status = in_progress`).
class RuleAction {
  final String type;
  final String value;

  const RuleAction({this.type = 'set_status', this.value = ''});

  RuleAction copyWith({String? type, String? value}) =>
      RuleAction(type: type ?? this.type, value: value ?? this.value);

  factory RuleAction.fromJson(Map<String, dynamic> json) => RuleAction(
    type: json['type'] as String? ?? 'set_status',
    value: json['value'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'value': value,
  };
}

/// A rule-based automation: when [trigger] fires and all [conditions] match,
/// run the [actions]. Manual JSON serialization per AGENTS.md §9.
class AutomationRule {
  final int id;
  final String name;
  final bool enabled;
  final String trigger;
  final List<RuleCondition> conditions;
  final List<RuleAction> actions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AutomationRule({
    required this.id,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.name = '',
    this.trigger = 'task_created',
    this.conditions = const <RuleCondition>[],
    this.actions = const <RuleAction>[],
  });

  factory AutomationRule.fromJson(Map<String, dynamic> json) => AutomationRule(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    trigger: json['trigger'] as String? ?? 'task_created',
    conditions: (json['conditions'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => RuleCondition.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    actions: (json['actions'] as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => RuleAction.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'enabled': enabled,
    'trigger': trigger,
    'conditions': conditions.map((RuleCondition c) => c.toJson()).toList(),
    'actions': actions.map((RuleAction a) => a.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  @override
  String toString() => 'AutomationRule(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutomationRule &&
          other.id == id &&
          other.name == name &&
          other.enabled == enabled &&
          other.trigger == trigger;

  @override
  int get hashCode => Object.hash(id, name, enabled, trigger);
}
