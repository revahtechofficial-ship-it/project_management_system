/// An international, national or awareness day: fixed to a Gregorian month and
/// day, and so recurring every year without a row per year.
///
/// Manual JSON per AGENTS.md §9.
class Observance {
  final int id;
  final int month;
  final int day;
  final String nameEn;
  final String nameNe;

  /// `international`, `national` or `awareness`.
  final String scope;

  final String noteEn;
  final String noteNe;

  /// Where the date came from. A day on the wrong date is worse than none.
  final String source;

  const Observance({
    required this.id,
    required this.month,
    required this.day,
    this.nameEn = '',
    this.nameNe = '',
    this.scope = 'international',
    this.noteEn = '',
    this.noteNe = '',
    this.source = '',
  });

  /// Whether it falls on [date] — matched by month and day, never by year.
  bool fallsOn(DateTime date) => date.month == month && date.day == day;

  String name({required bool nepali}) {
    if (nepali && nameNe.isNotEmpty) {
      return nameNe;
    }
    return nameEn.isNotEmpty ? nameEn : nameNe;
  }

  String note({required bool nepali}) {
    if (nepali && noteNe.isNotEmpty) {
      return noteNe;
    }
    return noteEn.isNotEmpty ? noteEn : noteNe;
  }

  static String _str(Map<String, dynamic> json, String key) =>
      json[key] as String? ?? '';

  factory Observance.fromJson(Map<String, dynamic> json) => Observance(
    id: json['id'] as int,
    month: json['month'] as int,
    day: json['day'] as int,
    nameEn: _str(json, 'name_en'),
    nameNe: _str(json, 'name_ne'),
    scope: _str(json, 'scope').isEmpty ? 'international' : _str(json, 'scope'),
    noteEn: _str(json, 'note_en'),
    noteNe: _str(json, 'note_ne'),
    source: _str(json, 'source'),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'month': month,
    'day': day,
    'name_en': nameEn,
    'name_ne': nameNe,
    'scope': scope,
    'note_en': noteEn,
    'note_ne': noteNe,
    'source': source,
  };

  @override
  String toString() => 'Observance($month/$day, $nameEn)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Observance &&
          other.id == id &&
          other.month == month &&
          other.day == day &&
          other.nameEn == nameEn &&
          other.nameNe == nameNe &&
          other.scope == scope &&
          other.noteEn == noteEn &&
          other.noteNe == noteNe &&
          other.source == source;

  @override
  int get hashCode => Object.hash(
    id,
    month,
    day,
    nameEn,
    nameNe,
    scope,
    noteEn,
    noteNe,
    source,
  );
}

/// The quote of the day. Chosen by the server, deterministically, from the day
/// of the year — so it does not change under the reader on a refresh.
class Quote {
  final int id;
  final String textEn;
  final String textNe;
  final String author;
  final String source;

  const Quote({
    required this.id,
    this.textEn = '',
    this.textNe = '',
    this.author = '',
    this.source = '',
  });

  String text({required bool nepali}) {
    if (nepali && textNe.isNotEmpty) {
      return textNe;
    }
    return textEn.isNotEmpty ? textEn : textNe;
  }

  static String _str(Map<String, dynamic> json, String key) =>
      json[key] as String? ?? '';

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    id: json['id'] as int,
    textEn: _str(json, 'text_en'),
    textNe: _str(json, 'text_ne'),
    author: _str(json, 'author'),
    source: _str(json, 'source'),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'text_en': textEn,
    'text_ne': textNe,
    'author': author,
    'source': source,
  };

  @override
  String toString() => 'Quote(id: $id, $author)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Quote &&
          other.id == id &&
          other.textEn == textEn &&
          other.textNe == textNe &&
          other.author == author &&
          other.source == source;

  @override
  int get hashCode => Object.hash(id, textEn, textNe, author, source);
}

/// One horoscope reading, for one sign over one period.
///
/// There is no algorithm behind this — a rashifal is written by an astrologer,
/// not computed — so the table is empty until somebody enters one, and
/// [source] records whose reading it is.
class Rashifal {
  final int id;

  /// 0 = Mesh (Aries) .. 11 = Meen (Pisces).
  final int rashi;

  /// `daily`, `weekly` or `monthly`.
  final String period;

  final DateTime fromDate;
  final DateTime toDate;
  final String textEn;
  final String textNe;
  final String source;

  const Rashifal({
    required this.id,
    required this.rashi,
    required this.fromDate,
    required this.toDate,
    this.period = 'daily',
    this.textEn = '',
    this.textNe = '',
    this.source = '',
  });

  String text({required bool nepali}) {
    if (nepali && textNe.isNotEmpty) {
      return textNe;
    }
    return textEn.isNotEmpty ? textEn : textNe;
  }

  static String _str(Map<String, dynamic> json, String key) =>
      json[key] as String? ?? '';

  factory Rashifal.fromJson(Map<String, dynamic> json) => Rashifal(
    id: json['id'] as int,
    rashi: json['rashi'] as int,
    period: _str(json, 'period').isEmpty ? 'daily' : _str(json, 'period'),
    fromDate: DateTime.parse(json['from_date'] as String),
    toDate: DateTime.parse(json['to_date'] as String),
    textEn: _str(json, 'text_en'),
    textNe: _str(json, 'text_ne'),
    source: _str(json, 'source'),
  );

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'rashi': rashi,
    'period': period,
    'from_date': _ymd(fromDate),
    'to_date': _ymd(toDate),
    'text_en': textEn,
    'text_ne': textNe,
    'source': source,
  };

  @override
  String toString() => 'Rashifal(rashi: $rashi, $period)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rashifal &&
          other.id == id &&
          other.rashi == rashi &&
          other.period == period &&
          other.fromDate == fromDate &&
          other.toDate == toDate &&
          other.textEn == textEn &&
          other.textNe == textNe &&
          other.source == source;

  @override
  int get hashCode =>
      Object.hash(id, rashi, period, fromDate, toDate, textEn, textNe, source);
}
