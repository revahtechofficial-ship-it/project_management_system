/// A measurable key result (a target) under an [Objective]. Manual JSON
/// serialization per AGENTS.md §9.
class KeyResult {
  final int id;
  final int objectiveId;
  final String title;
  final double startValue;
  final double currentValue;
  final double targetValue;
  final String unit;
  final double progress;

  const KeyResult({
    required this.id,
    required this.objectiveId,
    this.title = '',
    this.startValue = 0,
    this.currentValue = 0,
    this.targetValue = 100,
    this.unit = '',
    this.progress = 0,
  });

  /// A compact "current / target unit" label, e.g. `40 / 100 %`.
  String get valueLabel {
    final String c = _fmt(currentValue);
    final String t = _fmt(targetValue);
    return unit.isEmpty ? '$c / $t' : '$c / $t $unit';
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  factory KeyResult.fromJson(Map<String, dynamic> json) => KeyResult(
    id: json['id'] as int,
    objectiveId: json['objective_id'] as int,
    title: json['title'] as String? ?? '',
    startValue: (json['start_value'] as num?)?.toDouble() ?? 0,
    currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
    targetValue: (json['target_value'] as num?)?.toDouble() ?? 100,
    unit: json['unit'] as String? ?? '',
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'objective_id': objectiveId,
    'title': title,
    'start_value': startValue,
    'current_value': currentValue,
    'target_value': targetValue,
    'unit': unit,
    'progress': progress,
  };

  @override
  String toString() => 'KeyResult(id: $id, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyResult &&
          other.id == id &&
          other.title == title &&
          other.startValue == startValue &&
          other.currentValue == currentValue &&
          other.targetValue == targetValue &&
          other.unit == unit;

  @override
  int get hashCode =>
      Object.hash(id, title, startValue, currentValue, targetValue, unit);
}
