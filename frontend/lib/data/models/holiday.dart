import '../enums/festival_category.dart';

/// A piece of festival prose in both languages. Reading it in one language
/// falls back to the other, because a translation is often missing.
///
/// Manual JSON per AGENTS.md §9. Not serialized on its own: [Holiday] flattens
/// these onto `*_en` / `*_ne` keys to match the API.
class Bilingual {
  const Bilingual({this.en = '', this.ne = ''});

  final String en;
  final String ne;

  bool get isEmpty => en.isEmpty && ne.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// The text in the requested language, falling back to the other.
  String text({required bool nepali}) {
    if (nepali && ne.isNotEmpty) {
      return ne;
    }
    return en.isNotEmpty ? en : ne;
  }

  /// True when the requested language has no text of its own, and the other
  /// language is standing in for it.
  bool isFallback({required bool nepali}) =>
      isNotEmpty && (nepali ? ne.isEmpty : en.isEmpty);

  @override
  String toString() => 'Bilingual(en: $en, ne: $ne)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bilingual && other.en == en && other.ne == ne;

  @override
  int get hashCode => Object.hash(en, ne);
}

/// A calendar holiday or festival, from `/api/v1/holidays`. Stored against the
/// Gregorian date; the UI renders it against both AD and BS.
class Holiday {
  final int id;
  final DateTime date;
  final String nameEn;
  final String nameNe;
  final bool isPublic;
  final FestivalCategory category;
  final Bilingual description;
  final Bilingual history;
  final Bilingual importance;
  final Bilingual celebration;

  const Holiday({
    required this.id,
    required this.date,
    this.nameEn = '',
    this.nameNe = '',
    this.isPublic = true,
    this.category = FestivalCategory.other,
    this.description = const Bilingual(),
    this.history = const Bilingual(),
    this.importance = const Bilingual(),
    this.celebration = const Bilingual(),
  });

  /// The holiday name in the requested language, falling back to the other.
  String name({required bool nepali}) {
    if (nepali) {
      return nameNe.isNotEmpty ? nameNe : nameEn;
    }
    return nameEn.isNotEmpty ? nameEn : nameNe;
  }

  /// Whether anything beyond the name and date has been written for this day.
  bool get hasDetails =>
      description.isNotEmpty ||
      history.isNotEmpty ||
      importance.isNotEmpty ||
      celebration.isNotEmpty;

  static String _str(Map<String, dynamic> json, String key) =>
      json[key] as String? ?? '';

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
    id: json['id'] as int,
    date: DateTime.parse(json['date'] as String),
    nameEn: _str(json, 'name_en'),
    nameNe: _str(json, 'name_ne'),
    isPublic: json['is_public'] as bool? ?? true,
    category: FestivalCategory.fromJson(_str(json, 'category')),
    description: Bilingual(
      en: _str(json, 'description_en'),
      ne: _str(json, 'description_ne'),
    ),
    history: Bilingual(
      en: _str(json, 'history_en'),
      ne: _str(json, 'history_ne'),
    ),
    importance: Bilingual(
      en: _str(json, 'importance_en'),
      ne: _str(json, 'importance_ne'),
    ),
    celebration: Bilingual(
      en: _str(json, 'celebration_en'),
      ne: _str(json, 'celebration_ne'),
    ),
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
    'category': category.toJson(),
    'description_en': description.en,
    'description_ne': description.ne,
    'history_en': history.en,
    'history_ne': history.ne,
    'importance_en': importance.en,
    'importance_ne': importance.ne,
    'celebration_en': celebration.en,
    'celebration_ne': celebration.ne,
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
          other.isPublic == isPublic &&
          other.category == category &&
          other.description == description &&
          other.history == history &&
          other.importance == importance &&
          other.celebration == celebration;

  @override
  int get hashCode => Object.hash(
    id,
    date,
    nameEn,
    nameNe,
    isPublic,
    category,
    description,
    history,
    importance,
    celebration,
  );
}
