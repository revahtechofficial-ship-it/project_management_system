/// A calendar holiday, from `/api/v1/holidays`. Stored against the Gregorian
/// date; the UI renders it against both AD and BS. Manual JSON per AGENTS.md §9.
class Holiday {
  final int id;
  final DateTime date;
  final String nameEn;
  final String nameNe;
  final bool isPublic;

  const Holiday({
    required this.id,
    required this.date,
    this.nameEn = '',
    this.nameNe = '',
    this.isPublic = true,
  });

  /// The holiday name in the requested language, falling back to the other.
  String name({required bool nepali}) {
    if (nepali) {
      return nameNe.isNotEmpty ? nameNe : nameEn;
    }
    return nameEn.isNotEmpty ? nameEn : nameNe;
  }

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
    id: json['id'] as int,
    date: DateTime.parse(json['date'] as String),
    nameEn: json['name_en'] as String? ?? '',
    nameNe: json['name_ne'] as String? ?? '',
    isPublic: json['is_public'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'name_en': nameEn,
    'name_ne': nameNe,
    'is_public': isPublic,
  };

  @override
  String toString() => 'Holiday(id: $id, $nameEn)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Holiday &&
          other.id == id &&
          other.date == date &&
          other.nameEn == nameEn &&
          other.nameNe == nameNe &&
          other.isPublic == isPublic;

  @override
  int get hashCode => Object.hash(id, date, nameEn, nameNe, isPublic);
}
