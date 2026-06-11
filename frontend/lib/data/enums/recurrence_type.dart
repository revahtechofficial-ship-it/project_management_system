/// How often a task recurs. Tied to the `Task` model, so it carries
/// `toJson` / `fromJson` with a sentinel default (AGENTS.md §9 Enums).
enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  other;

  String get label => switch (this) {
        RecurrenceType.none => 'Does not repeat',
        RecurrenceType.daily => 'Daily',
        RecurrenceType.weekly => 'Weekly',
        RecurrenceType.monthly => 'Monthly',
        RecurrenceType.other => 'Custom',
      };

  bool get repeats => this != RecurrenceType.none && this != RecurrenceType.other;

  String toJson() => switch (this) {
        RecurrenceType.none => 'none',
        RecurrenceType.daily => 'daily',
        RecurrenceType.weekly => 'weekly',
        RecurrenceType.monthly => 'monthly',
        RecurrenceType.other => '',
      };

  factory RecurrenceType.fromJson(String value) => switch (value) {
        'none' => RecurrenceType.none,
        'daily' => RecurrenceType.daily,
        'weekly' => RecurrenceType.weekly,
        'monthly' => RecurrenceType.monthly,
        _ => RecurrenceType.none,
      };

  /// Values offered in the recurrence dropdown.
  static List<RecurrenceType> get selectableValues => <RecurrenceType>[
        RecurrenceType.none,
        RecurrenceType.daily,
        RecurrenceType.weekly,
        RecurrenceType.monthly,
      ];
}
