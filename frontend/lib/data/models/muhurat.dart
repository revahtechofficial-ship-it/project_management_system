import '../enums/muhurat_kind.dart';

/// A saait: an auspicious window for a ceremony, from `/api/v1/muhurats`.
///
/// Unlike Rahu Kaal — which the client computes from the length of the day —
/// a saait is published by a panchang committee and typed in. [source] records
/// which list it came from, because committees differ and a wrong row should
/// be traceable.
///
/// Manual JSON per AGENTS.md §9.
class Muhurat {
  final int id;
  final DateTime date;
  final MuhuratKind kind;

  /// `HH:MM`, or empty when the whole day is auspicious.
  final String startTime;
  final String endTime;

  final String noteEn;
  final String noteNe;
  final String source;

  const Muhurat({
    required this.id,
    required this.date,
    this.kind = MuhuratKind.other,
    this.startTime = '',
    this.endTime = '',
    this.noteEn = '',
    this.noteNe = '',
    this.source = '',
  });

  /// True when no window was given, so the whole day counts.
  bool get isAllDay => startTime.isEmpty || endTime.isEmpty;

  /// `09:15 – 11:40`, or `All day`.
  String window({required bool nepali}) {
    if (isAllDay) {
      return nepali ? 'दिनभर' : 'All day';
    }
    return '$startTime – $endTime';
  }

  /// The note in the requested language, falling back to the other.
  String note({required bool nepali}) {
    if (nepali && noteNe.isNotEmpty) {
      return noteNe;
    }
    return noteEn.isNotEmpty ? noteEn : noteNe;
  }

  static String _str(Map<String, dynamic> json, String key) =>
      json[key] as String? ?? '';

  factory Muhurat.fromJson(Map<String, dynamic> json) => Muhurat(
    id: json['id'] as int,
    date: DateTime.parse(json['date'] as String),
    kind: MuhuratKind.fromJson(_str(json, 'kind')),
    startTime: _str(json, 'start_time'),
    endTime: _str(json, 'end_time'),
    noteEn: _str(json, 'note_en'),
    noteNe: _str(json, 'note_ne'),
    source: _str(json, 'source'),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'kind': kind.toJson(),
    'start_time': startTime,
    'end_time': endTime,
    'note_en': noteEn,
    'note_ne': noteNe,
    'source': source,
  };

  @override
  String toString() => 'Muhurat(id: $id, ${kind.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Muhurat &&
          other.id == id &&
          other.date == date &&
          other.kind == kind &&
          other.startTime == startTime &&
          other.endTime == endTime &&
          other.noteEn == noteEn &&
          other.noteNe == noteNe &&
          other.source == source;

  @override
  int get hashCode =>
      Object.hash(id, date, kind, startTime, endTime, noteEn, noteNe, source);
}
