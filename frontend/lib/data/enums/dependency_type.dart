/// The four classic task-dependency relationships. Tied to the
/// `TaskDependency` model, so it carries `toJson` / `fromJson` with a sentinel
/// default (AGENTS.md §9 Enums).
enum DependencyType {
  finishToStart,
  startToStart,
  finishToFinish,
  startToFinish,
  other;

  String get label => switch (this) {
    DependencyType.finishToStart => 'Finish → Start',
    DependencyType.startToStart => 'Start → Start',
    DependencyType.finishToFinish => 'Finish → Finish',
    DependencyType.startToFinish => 'Start → Finish',
    DependencyType.other => 'Dependency',
  };

  String get shortLabel => switch (this) {
    DependencyType.finishToStart => 'FS',
    DependencyType.startToStart => 'SS',
    DependencyType.finishToFinish => 'FF',
    DependencyType.startToFinish => 'SF',
    DependencyType.other => '—',
  };

  String toJson() => switch (this) {
    DependencyType.finishToStart => 'finish_to_start',
    DependencyType.startToStart => 'start_to_start',
    DependencyType.finishToFinish => 'finish_to_finish',
    DependencyType.startToFinish => 'start_to_finish',
    DependencyType.other => '',
  };

  factory DependencyType.fromJson(String value) => switch (value) {
    'finish_to_start' => DependencyType.finishToStart,
    'start_to_start' => DependencyType.startToStart,
    'finish_to_finish' => DependencyType.finishToFinish,
    'start_to_finish' => DependencyType.startToFinish,
    _ => DependencyType.other,
  };

  /// The types the UI offers when creating a dependency (excludes the
  /// sentinel).
  static List<DependencyType> get selectableValues => <DependencyType>[
    DependencyType.finishToStart,
    DependencyType.startToStart,
    DependencyType.finishToFinish,
    DependencyType.startToFinish,
  ];
}
