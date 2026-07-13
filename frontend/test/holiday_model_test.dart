import 'package:flutter_test/flutter_test.dart';
import 'package:revahms_web/data/enums/festival_category.dart';
import 'package:revahms_web/data/models/holiday.dart';

void main() {
  group('Bilingual', () {
    test('reads the requested language when it has text', () {
      const Bilingual b = Bilingual(en: 'Dashain', ne: 'दशैं');
      expect(b.text(nepali: true), 'दशैं');
      expect(b.text(nepali: false), 'Dashain');
      expect(b.isFallback(nepali: true), isFalse);
      expect(b.isFallback(nepali: false), isFalse);
    });

    test('falls back to the other language, and says that it did', () {
      const Bilingual onlyEn = Bilingual(en: 'A solar observance.');
      expect(onlyEn.text(nepali: true), 'A solar observance.');
      expect(onlyEn.isFallback(nepali: true), isTrue);
      expect(onlyEn.isFallback(nepali: false), isFalse);

      const Bilingual onlyNe = Bilingual(ne: 'सूर्य पूजा।');
      expect(onlyNe.text(nepali: false), 'सूर्य पूजा।');
      expect(onlyNe.isFallback(nepali: false), isTrue);
    });

    test('an empty pair is never a fallback', () {
      const Bilingual empty = Bilingual();
      expect(empty.isEmpty, isTrue);
      expect(empty.text(nepali: true), '');
      expect(empty.isFallback(nepali: true), isFalse);
    });
  });

  group('Holiday JSON', () {
    Map<String, dynamic> json() => <String, dynamic>{
      'id': 7,
      'date': '2026-10-20',
      'name_en': 'Vijaya Dashami',
      'name_ne': 'विजया दशमी',
      'is_public': true,
      'category': 'religious',
      'description_en': 'The tenth day of Dashain.',
      'description_ne': 'दशैंको मुख्य दिन।',
      'history_en': 'Durga defeats Mahishasura.',
      'history_ne': '',
      'importance_en': 'Family reunion.',
      'importance_ne': '',
      'celebration_en': 'Elders give tika and jamara.',
      'celebration_ne': '',
    };

    test('round-trips through fromJson and toJson', () {
      final Holiday holiday = Holiday.fromJson(json());
      expect(holiday.toJson(), json());
    });

    test('reads the nested prose', () {
      final Holiday holiday = Holiday.fromJson(json());
      expect(holiday.category, FestivalCategory.religious);
      expect(holiday.description.ne, 'दशैंको मुख्य दिन।');
      expect(holiday.history.isFallback(nepali: true), isTrue);
      expect(holiday.hasDetails, isTrue);
    });

    test('survives a payload with only the required keys', () {
      final Holiday bare = Holiday.fromJson(<String, dynamic>{
        'id': 1,
        'date': '2026-01-01',
      });
      expect(bare.nameEn, '');
      expect(bare.isPublic, isTrue);
      expect(bare.category, FestivalCategory.other);
      expect(bare.hasDetails, isFalse);
    });

    test('an unknown category degrades to other rather than throwing', () {
      final Holiday odd = Holiday.fromJson(<String, dynamic>{
        'id': 1,
        'date': '2026-01-01',
        'category': 'lunar-eclipse-party',
      });
      expect(odd.category, FestivalCategory.other);
    });

    test('name falls back across languages', () {
      final Holiday onlyNe = Holiday(
        id: 1,
        date: DateTime(2026, 11, 8),
        nameNe: 'तिहार',
      );
      expect(onlyNe.name(nepali: false), 'तिहार');

      final Holiday onlyEn = Holiday(
        id: 2,
        date: DateTime(2026, 11, 8),
        nameEn: 'Tihar',
      );
      expect(onlyEn.name(nepali: true), 'Tihar');
    });
  });
}
