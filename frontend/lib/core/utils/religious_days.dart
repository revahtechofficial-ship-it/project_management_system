import 'nepali_calendar.dart';
import 'panchang.dart';

// Which fasts and observances fall on a day (AGENTS.md §1 `core/utils`).
//
// All of these follow from the panchang, so none of them is stored: an
// Ekadashi is simply the eleventh tithi, a Purnima the fifteenth, an Aunsi the
// thirtieth, and a Sankranti the day the sun crosses into a new sign — which
// is, by construction, the first day of a Bikram Sambat month.
//
// One thing here is *not* computed, and the card says so. The tithi is a fact,
// but the day a fast is *kept* is a ruling: Vaishnavas and Smartas keep the
// same Ekadashi on different days when the tithi does not sit cleanly around
// sunrise. That split is a matter of religious authority, not arithmetic, so
// this names the tithi's own day and leaves the ruling alone.

/// The twelve signs, in the order the sun enters them. Baishakh opens with the
/// sun entering Mesh, so BS month M opens with the sankranti of sign M-1.
const List<String> _rasiEn = <String>[
  'Mesh',
  'Vrish',
  'Mithun',
  'Karkat',
  'Simha',
  'Kanya',
  'Tula',
  'Vrishchik',
  'Dhanu',
  'Makar',
  'Kumbha',
  'Meen',
];

const List<String> _rasiNe = <String>[
  'मेष',
  'वृष',
  'मिथुन',
  'कर्कट',
  'सिंह',
  'कन्या',
  'तुला',
  'वृश्चिक',
  'धनु',
  'मकर',
  'कुम्भ',
  'मीन',
];

/// The twenty-four Ekadashis, named by the *purnimanta* lunar month and the
/// half they fall in — see [purnimantaMonth]. Indexed by month 1-12.
const List<String> _ekadashiShukla = <String>[
  '',
  'Kamada', // Chaitra
  'Mohini', // Baishakh
  'Nirjala', // Jestha
  'Devshayani', // Ashadh
  'Putrada', // Shrawan
  'Parsva', // Bhadra
  'Papankusha', // Ashwin
  'Prabodhini', // Kartik
  'Mokshada', // Mangsir
  'Putrada', // Poush
  'Jaya', // Magh
  'Amalaki', // Falgun
];

const List<String> _ekadashiKrishna = <String>[
  '',
  'Papmochani', // Chaitra
  'Varuthini', // Baishakh
  'Apara', // Jestha
  'Yogini', // Ashadh
  'Kamika', // Shrawan
  'Aja', // Bhadra
  'Indira', // Ashwin
  'Rama', // Kartik
  'Utpanna', // Mangsir
  'Saphala', // Poush
  'Shattila', // Magh
  'Vijaya', // Falgun
];

/// The lunar month a day belongs to under the *purnimanta* reckoning, which is
/// what Nepal uses to name its fasts.
///
/// A purnimanta month runs full moon to full moon, an amanta month new moon to
/// new moon. They agree on the bright half and disagree on the dark: the dark
/// half of amanta month M is the dark half of purnimanta month M+1.
///
/// This is not a detail. The Ekadashi of 11 July 2026 falls in the dark half of
/// amanta Jestha — and Nepal calls it Yogini, which is the *Ashadh* Ekadashi.
/// Name it from the amanta month and every dark-half fast in the year comes out
/// one month wrong.
int purnimantaMonth(int amantaMonth, Paksha paksha) {
  if (paksha == Paksha.shukla) {
    return amantaMonth;
  }
  return amantaMonth % 12 + 1;
}

/// One of the twelve rashis.
class Rashi {
  const Rashi(this.index, this.nameEn, this.nameNe, this.westernName);

  /// 0 = Mesh (Aries).
  final int index;
  final String nameEn;
  final String nameNe;

  /// The Western name of the same sign — the same twelfth of the sky, read
  /// against a zodiac that has drifted about 24° since it was named.
  final String westernName;

  String name({required bool nepali}) => nepali ? nameNe : nameEn;

  @override
  String toString() => nameEn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Rashi && other.index == index;

  @override
  int get hashCode => index;
}

const List<String> _westernNames = <String>[
  'Aries',
  'Taurus',
  'Gemini',
  'Cancer',
  'Leo',
  'Virgo',
  'Libra',
  'Scorpio',
  'Sagittarius',
  'Capricorn',
  'Aquarius',
  'Pisces',
];

/// The rashi of an index, 0 = Mesh.
Rashi rashiOf(int index) {
  final int i = index % 12;
  return Rashi(i, _rasiEn[i], _rasiNe[i], _westernNames[i]);
}

/// The sign the *moon* stands in on [date] — the rashi a Nepali reader means
/// by "my rashi", and the one a daily rashifal is written against.
///
/// Not the Western sun sign: that is the sun's place against a *tropical*
/// zodiac, which has drifted some 24° from the stars since it was named. The
/// two disagree for most people, which is why so many are surprised to be a
/// different sign here.
Rashi moonRashiOn(DateTime date) {
  // Straight off the moon's sidereal longitude — a rashi is a clean 30° of it.
  // Deriving it from the nakshatra instead would be wrong: a nakshatra is
  // 13°20' and so straddles rashi boundaries.
  return rashiOf((panchangFor(date).moonSidereal / 30).floor());
}

/// The sign the *sun* stands in on [date], sidereally — the sankranti sign,
/// and the one the Bikram Sambat months are cut from.
Rashi sunRashiOn(DateTime date) =>
    rashiOf((panchangFor(date).sunSidereal / 30).floor());

/// One observance, and why it is one.
class ReligiousDay {
  const ReligiousDay({
    required this.nameEn,
    required this.nameNe,
    required this.kind,
    this.isFast = false,
    this.noteEn = '',
    this.noteNe = '',
  });

  final String nameEn;
  final String nameNe;
  final ReligiousKind kind;

  /// Whether it is traditionally kept as a fast (brata).
  final bool isFast;

  final String noteEn;
  final String noteNe;

  String name({required bool nepali}) => nepali ? nameNe : nameEn;
  String note({required bool nepali}) => nepali ? noteNe : noteEn;

  @override
  String toString() => nameEn;
}

/// What kind of day it is.
enum ReligiousKind {
  ekadashi,
  purnima,
  aunsi,
  sankranti,
  brata,
  puja;

  String get label => switch (this) {
    ReligiousKind.ekadashi => 'Ekadashi',
    ReligiousKind.purnima => 'Purnima',
    ReligiousKind.aunsi => 'Aunsi',
    ReligiousKind.sankranti => 'Sankranti',
    ReligiousKind.brata => 'Brata',
    ReligiousKind.puja => 'Puja',
  };

  String get labelNe => switch (this) {
    ReligiousKind.ekadashi => 'एकादशी',
    ReligiousKind.purnima => 'पूर्णिमा',
    ReligiousKind.aunsi => 'औंसी',
    ReligiousKind.sankranti => 'संक्रान्ति',
    ReligiousKind.brata => 'व्रत',
    ReligiousKind.puja => 'पूजा',
  };
}

/// Everything the panchang says about [date] religiously.
///
/// Empty on most days: a fortnight has one Ekadashi, one Chaturdashi and one
/// Pradosh, and the days between are ordinary.
List<ReligiousDay> religiousDaysFor(DateTime date) {
  final Panchang p = panchangFor(date);
  final BsDate bs = adToBs(date);
  final List<ReligiousDay> days = <ReligiousDay>[];

  // The tithi within its half: 1-15 in either paksha.
  final int t = p.tithi.index <= 15 ? p.tithi.index : p.tithi.index - 15;
  final bool shukla = p.paksha == Paksha.shukla;

  // A sankranti is the sun entering a sign, and a BS month begins on exactly
  // that day. So the first of any BS month *is* a sankranti — no separate
  // calculation, and no chance of the two disagreeing.
  if (bs.day == 1) {
    final int rasi = (bs.month - 1) % 12;
    days.add(
      ReligiousDay(
        nameEn: '${_rasiEn[rasi]} Sankranti',
        nameNe: '${_rasiNe[rasi]} संक्रान्ति',
        kind: ReligiousKind.sankranti,
        noteEn:
            'The sun enters ${_rasiEn[rasi]}, and ${kBsMonthsEn[bs.month]} '
            'begins.',
        noteNe: 'सूर्य ${_rasiNe[rasi]} राशिमा प्रवेश गर्छ।',
      ),
    );
  }

  switch (t) {
    case 4:
      days.add(
        ReligiousDay(
          nameEn: shukla ? 'Vinayaka Chaturthi' : 'Sankashti Chaturthi',
          nameNe: shukla ? 'विनायक चतुर्थी' : 'सङ्कष्टी चतुर्थी',
          kind: ReligiousKind.brata,
          isFast: true,
          noteEn: 'Kept for Ganesh.',
          noteNe: 'गणेशको व्रत।',
        ),
      );
    case 8:
      days.add(
        ReligiousDay(
          nameEn: shukla ? 'Durga Ashtami' : 'Kalashtami',
          nameNe: shukla ? 'दुर्गा अष्टमी' : 'कालाष्टमी',
          kind: ReligiousKind.brata,
          isFast: true,
        ),
      );
    case 11:
      final int month = purnimantaMonth(p.lunarMonthIndex, p.paksha);
      final String name = shukla
          ? _ekadashiShukla[month]
          : _ekadashiKrishna[month];
      days.add(
        ReligiousDay(
          nameEn: '$name Ekadashi',
          nameNe: '$name एकादशी',
          kind: ReligiousKind.ekadashi,
          isFast: true,
          // The tithi is arithmetic; the day the fast is *kept* is a ruling,
          // and the two sects do not always rule the same way.
          noteEn:
              'A fast day. Vaishnavas and Smartas may keep it on '
              'different days when the tithi does not span sunrise cleanly.',
          noteNe: 'व्रतको दिन। वैष्णव र स्मार्तले फरक दिन पनि बस्न सक्छन्।',
        ),
      );
    case 13:
      days.add(
        const ReligiousDay(
          nameEn: 'Pradosh Brata',
          nameNe: 'प्रदोष व्रत',
          kind: ReligiousKind.brata,
          isFast: true,
          noteEn: 'Kept for Shiva, in the twilight before nightfall.',
          noteNe: 'साँझको समयमा शिवको व्रत।',
        ),
      );
    case 15:
      if (shukla) {
        days.add(
          const ReligiousDay(
            nameEn: 'Purnima',
            nameNe: 'पूर्णिमा',
            kind: ReligiousKind.purnima,
            isFast: true,
            noteEn: 'The full moon.',
            noteNe: 'पूर्ण चन्द्र।',
          ),
        );
      } else {
        days.add(
          const ReligiousDay(
            nameEn: 'Aunsi (Amavasya)',
            nameNe: 'औंसी (अमावस्या)',
            kind: ReligiousKind.aunsi,
            isFast: true,
            noteEn: 'The new moon; a day for the ancestors.',
            noteNe: 'नयाँ चन्द्र; पितृको दिन।',
          ),
        );
      }
    case 14:
      if (!shukla) {
        days.add(
          const ReligiousDay(
            nameEn: 'Shiva Chaturdashi',
            nameNe: 'शिव चतुर्दशी',
            kind: ReligiousKind.puja,
            noteEn: 'Masik Shivaratri — the monthly night of Shiva.',
            noteNe: 'मासिक शिवरात्री।',
          ),
        );
      }
  }

  return days;
}

/// True when the day carries a fast of any kind.
bool isFastDay(DateTime date) =>
    religiousDaysFor(date).any((ReligiousDay d) => d.isFast);
