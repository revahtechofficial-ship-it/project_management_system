import 'package:flutter_test/flutter_test.dart';
import 'package:revahms_web/core/utils/nepali_calendar.dart';

/// Every (BS, AD) pair published in the BS 2083 festival list the owner
/// supplied. The list states both calendars for each day, so it is an
/// independent check on `bsToAd` — 44 data points from a source that has no
/// connection to `nepali_utils`.
///
/// Keep these here rather than in nepali_calendar_test.dart: if a future data
/// correction changes a row, the failure should point at the source, not at
/// the conversion code.
const List<(int, int, int, String)> _bs2083 = <(int, int, int, String)>[
  (2083, 1, 1, '2026-04-14'), // Nepali New Year
  (2083, 1, 18, '2026-05-01'), // Buddha Jayanti / Labour Day
  (2083, 2, 14, '2026-05-28'), // Bakar Eid
  (2083, 2, 15, '2026-05-29'), // Republic Day
  (2083, 3, 6, '2026-06-20'), // Bhoto Jatra
  (2083, 5, 12, '2026-08-28'), // Janai Purnima / Raksha Bandhan
  (2083, 5, 13, '2026-08-29'), // Gai Jatra
  (2083, 5, 19, '2026-09-04'), // Krishna Janmashtami / Gaura Parva
  (2083, 5, 29, '2026-09-14'), // Hartalika Teej
  (2083, 6, 3, '2026-09-19'), // Constitution Day
  (2083, 6, 9, '2026-09-25'), // Indra Jatra
  (2083, 6, 18, '2026-10-04'), // Jitiya Parva
  (2083, 6, 25, '2026-10-11'), // Ghatasthapana
  (2083, 6, 31, '2026-10-17'), // Fulpati
  (2083, 7, 1, '2026-10-18'), // Maha Ashtami
  (2083, 7, 2, '2026-10-19'), // Dashain holiday
  (2083, 7, 3, '2026-10-20'), // Maha Navami
  (2083, 7, 4, '2026-10-21'), // Vijaya Dashami
  (2083, 7, 5, '2026-10-22'), // Ekadashi
  (2083, 7, 6, '2026-10-23'), // Dwadashi
  (2083, 7, 22, '2026-11-08'), // Laxmi Puja
  (2083, 7, 23, '2026-11-09'), // Gai Puja
  (2083, 7, 24, '2026-11-10'), // Govardhan Puja / Mha Puja
  (2083, 7, 25, '2026-11-11'), // Bhai Tika
  (2083, 7, 26, '2026-11-12'), // Tihar holiday
  (2083, 7, 29, '2026-11-15'), // Chhath
  (2083, 8, 8, '2026-11-24'), // Guru Nanak Jayanti
  (2083, 8, 17, '2026-12-03'), // Disabled Persons Day
  (2083, 8, 18, '2026-12-04'), // Udhauli / Utpatika Ekadashi
  (2083, 9, 9, '2026-12-24'), // Dhanya Purnima / Yomari Punhi
  (2083, 9, 10, '2026-12-25'), // Christmas
  (2083, 9, 15, '2026-12-30'), // Tamu Losar
  (2083, 9, 27, '2027-01-11'), // Prithvi Jayanti
  (2083, 10, 1, '2027-01-15'), // Maghe Sankranti
  (2083, 10, 16, '2027-01-30'), // Martyrs' Day
  (2083, 10, 24, '2027-02-07'), // Sonam Losar
  (2083, 10, 28, '2027-02-11'), // Saraswati Puja
  (2083, 11, 7, '2027-02-19'), // Prajatantra Diwas
  (2083, 11, 22, '2027-03-06'), // Maha Shivaratri
  (2083, 11, 24, '2027-03-08'), // International Women's Day
  (2083, 11, 25, '2027-03-09'), // Gyalpo Losar
  (2083, 12, 7, '2027-03-21'), // Fagu Purnima / Holi (hills)
  (2083, 12, 8, '2027-03-22'), // Fagu Purnima (Terai)
  (2083, 12, 23, '2027-04-06'), // Ghode Jatra
];

void main() {
  group('BS 2083 published list', () {
    test('every published BS date converts to its published AD date', () {
      for (final (int y, int m, int d, String ad) in _bs2083) {
        expect(
          dayKey(bsToAd(y, m, d)),
          ad,
          reason: 'BS $y-$m-$d should be $ad',
        );
      }
    });

    test('and back again', () {
      for (final (int y, int m, int d, String ad) in _bs2083) {
        expect(adToBs(DateTime.parse(ad)), BsDate(y, m, d), reason: ad);
      }
    });
  });
}
