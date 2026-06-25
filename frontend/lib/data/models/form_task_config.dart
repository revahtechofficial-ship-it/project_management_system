/// The "create a task from each submission" setting on a form (Automatic Task
/// Creation from Forms). Stored in the form page body under `create_task`.
/// Manual JSON serialization per AGENTS.md §9.
class FormTaskConfig {
  final bool enabled;
  final int? projectId;
  final String titleField;
  final String priority;

  const FormTaskConfig({
    this.enabled = false,
    this.projectId,
    this.titleField = '',
    this.priority = 'none',
  });

  FormTaskConfig copyWith({
    bool? enabled,
    int? projectId,
    bool clearProject = false,
    String? titleField,
    String? priority,
  }) => FormTaskConfig(
    enabled: enabled ?? this.enabled,
    projectId: clearProject ? null : (projectId ?? this.projectId),
    titleField: titleField ?? this.titleField,
    priority: priority ?? this.priority,
  );

  factory FormTaskConfig.fromJson(Map<String, dynamic> json) => FormTaskConfig(
    enabled: json['enabled'] as bool? ?? false,
    projectId: (json['project_id'] as num?)?.toInt(),
    titleField: json['title_field'] as String? ?? '',
    priority: json['priority'] as String? ?? 'none',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'project_id': projectId,
    'title_field': titleField,
    'priority': priority,
  };

  @override
  String toString() =>
      'FormTaskConfig(enabled: $enabled, project: $projectId, '
      'titleField: $titleField, priority: $priority)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormTaskConfig &&
          other.enabled == enabled &&
          other.projectId == projectId &&
          other.titleField == titleField &&
          other.priority == priority;

  @override
  int get hashCode => Object.hash(enabled, projectId, titleField, priority);
}
