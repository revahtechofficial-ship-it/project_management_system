import 'dart:math' as math;

import 'astronomy.dart';
import 'nepali_calendar.dart';

// The panchang — the five limbs of the daily almanac (AGENTS.md §1
// `core/utils`), built on `astronomy.dart`.
//
// All five are functions of just two angles: the sun's and the moon's ecliptic
// longitudes. A tithi is 12° of the moon pulling away from the sun; a
// nakshatra is 13°20' of the moon against the fixed stars; a yoga is 13°20' of
// the two longitudes added together; a karana is half a tithi.
//
// A day takes the name of the element in force *at sunrise* — which is why
// two consecutive days can carry the same tithi (it did not end before the
// second sunrise) and why a tithi can be skipped entirely (it began and ended
// between two sunrises). Both are correct, and both appear in a printed patro.

/// Kathmandu, where Nepal's panchang is reckoned.
const double kKathmanduLatitude = 27.7172;
const double kKathmanduLongitude = 85.3240;

const List<String> _tithiEn = <String>[
  'Pratipada',
  'Dwitiya',
  'Tritiya',
  'Chaturthi',
  'Panchami',
  'Shashthi',
  'Saptami',
  'Ashtami',
  'Navami',
  'Dashami',
  'Ekadashi',
  'Dwadashi',
  'Trayodashi',
  'Chaturdashi',
];

const List<String> _tithiNe = <String>[
  'प्रतिपदा',
  'द्वितीया',
  'तृतीया',
  'चतुर्थी',
  'पञ्चमी',
  'षष्ठी',
  'सप्तमी',
  'अष्टमी',
  'नवमी',
  'दशमी',
  'एकादशी',
  'द्वादशी',
  'त्रयोदशी',
  'चतुर्दशी',
];

const List<String> _nakshatraEn = <String>[
  'Ashwini',
  'Bharani',
  'Krittika',
  'Rohini',
  'Mrigashira',
  'Ardra',
  'Punarvasu',
  'Pushya',
  'Ashlesha',
  'Magha',
  'Purva Phalguni',
  'Uttara Phalguni',
  'Hasta',
  'Chitra',
  'Swati',
  'Vishakha',
  'Anuradha',
  'Jyeshtha',
  'Mula',
  'Purva Ashadha',
  'Uttara Ashadha',
  'Shravana',
  'Dhanishta',
  'Shatabhisha',
  'Purva Bhadrapada',
  'Uttara Bhadrapada',
  'Revati',
];

const List<String> _nakshatraNe = <String>[
  'अश्विनी',
  'भरणी',
  'कृत्तिका',
  'रोहिणी',
  'मृगशिरा',
  'आर्द्रा',
  'पुनर्वसु',
  'पुष्य',
  'आश्लेषा',
  'मघा',
  'पूर्वाफाल्गुनी',
  'उत्तराफाल्गुनी',
  'हस्त',
  'चित्रा',
  'स्वाती',
  'विशाखा',
  'अनुराधा',
  'ज्येष्ठा',
  'मूल',
  'पूर्वाषाढा',
  'उत्तराषाढा',
  'श्रवण',
  'धनिष्ठा',
  'शतभिषा',
  'पूर्वाभाद्रपदा',
  'उत्तराभाद्रपदा',
  'रेवती',
];

const List<String> _yogaEn = <String>[
  'Vishkambha',
  'Priti',
  'Ayushman',
  'Saubhagya',
  'Shobhana',
  'Atiganda',
  'Sukarma',
  'Dhriti',
  'Shula',
  'Ganda',
  'Vriddhi',
  'Dhruva',
  'Vyaghata',
  'Harshana',
  'Vajra',
  'Siddhi',
  'Vyatipata',
  'Variyana',
  'Parigha',
  'Shiva',
  'Siddha',
  'Sadhya',
  'Shubha',
  'Shukla',
  'Brahma',
  'Indra',
  'Vaidhriti',
];

const List<String> _yogaNe = <String>[
  'विष्कम्भ',
  'प्रीति',
  'आयुष्मान्',
  'सौभाग्य',
  'शोभन',
  'अतिगण्ड',
  'सुकर्मा',
  'धृति',
  'शूल',
  'गण्ड',
  'वृद्धि',
  'ध्रुव',
  'व्याघात',
  'हर्षण',
  'वज्र',
  'सिद्धि',
  'व्यतिपात',
  'वरीयान',
  'परिघ',
  'शिव',
  'सिद्ध',
  'साध्य',
  'शुभ',
  'शुक्ल',
  'ब्रह्म',
  'इन्द्र',
  'वैधृति',
];

/// The seven karanas that repeat through the month.
const List<String> _movableKaranaEn = <String>[
  'Bava',
  'Balava',
  'Kaulava',
  'Taitila',
  'Gara',
  'Vanija',
  'Vishti',
];
const List<String> _movableKaranaNe = <String>[
  'बव',
  'बालव',
  'कौलव',
  'तैतिल',
  'गर',
  'वणिज',
  'विष्टि',
];

/// The four that occur once each, around the new moon.
const List<String> _fixedKaranaEn = <String>[
  'Kimstughna',
  'Shakuni',
  'Chatushpada',
  'Naga',
];
const List<String> _fixedKaranaNe = <String>[
  'किंस्तुघ्न',
  'शकुनि',
  'चतुष्पाद',
  'नाग',
];

/// The twelve lunar months, from Chaitra.
const List<String> _lunarMonthEn = <String>[
  'Chaitra',
  'Baishakh',
  'Jestha',
  'Ashadh',
  'Shrawan',
  'Bhadra',
  'Ashwin',
  'Kartik',
  'Mangsir',
  'Poush',
  'Magh',
  'Falgun',
];
const List<String> _lunarMonthNe = <String>[
  'चैत्र',
  'वैशाख',
  'ज्येष्ठ',
  'आषाढ',
  'श्रावण',
  'भाद्र',
  'आश्विन',
  'कार्तिक',
  'मार्गशीर्ष',
  'पौष',
  'माघ',
  'फाल्गुन',
];

/// One limb of the panchang: which one it is, and when it gives way to the
/// next.
class PanchangElement {
  const PanchangElement({
    required this.index,
    required this.nameEn,
    required this.nameNe,
    required this.endsAt,
  });

  /// One-based, so it reads as it does in a printed patro.
  final int index;
  final String nameEn;
  final String nameNe;

  /// The moment it ends, in Nepal time.
  final DateTime endsAt;

  String name({required bool nepali}) => nepali ? nameNe : nameEn;

  @override
  String toString() => '$nameEn (till $endsAt)';
}

/// The moon's phase — the *shape* of it, as against the tithi, which is the
/// count.
///
/// Both are read off the same angle: how far the moon has pulled ahead of the
/// sun. A tithi is 12° of that; a phase is an eighth of the whole turn. So they
/// move together but do not line up — Purnima is the fifteenth tithi, and the
/// moon is at its fullest somewhere inside it, not at its edge.
enum MoonPhase {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  fullMoon,
  waningGibbous,
  lastQuarter,
  waningCrescent;

  String get label => switch (this) {
    MoonPhase.newMoon => 'New moon',
    MoonPhase.waxingCrescent => 'Waxing crescent',
    MoonPhase.firstQuarter => 'First quarter',
    MoonPhase.waxingGibbous => 'Waxing gibbous',
    MoonPhase.fullMoon => 'Full moon',
    MoonPhase.waningGibbous => 'Waning gibbous',
    MoonPhase.lastQuarter => 'Last quarter',
    MoonPhase.waningCrescent => 'Waning crescent',
  };

  String get labelNe => switch (this) {
    MoonPhase.newMoon => 'औंसी',
    MoonPhase.waxingCrescent => 'बढ्दो चन्द्र',
    MoonPhase.firstQuarter => 'अर्ध चन्द्र (बढ्दो)',
    MoonPhase.waxingGibbous => 'बढ्दो पूर्ण चन्द्र',
    MoonPhase.fullMoon => 'पूर्णिमा',
    MoonPhase.waningGibbous => 'घट्दो पूर्ण चन्द्र',
    MoonPhase.lastQuarter => 'अर्ध चन्द्र (घट्दो)',
    MoonPhase.waningCrescent => 'घट्दो चन्द्र',
  };

  /// A glyph of the shape, which reads faster than the words do.
  String get symbol => switch (this) {
    MoonPhase.newMoon => '\u{1F311}',
    MoonPhase.waxingCrescent => '\u{1F312}',
    MoonPhase.firstQuarter => '\u{1F313}',
    MoonPhase.waxingGibbous => '\u{1F314}',
    MoonPhase.fullMoon => '\u{1F315}',
    MoonPhase.waningGibbous => '\u{1F316}',
    MoonPhase.lastQuarter => '\u{1F317}',
    MoonPhase.waningCrescent => '\u{1F318}',
  };

  String phaseName({required bool nepali}) => nepali ? labelNe : label;
}

/// The phase an elongation falls in.
///
/// Eight phases of 45° each, *centred* on their names rather than beginning at
/// them: the full moon is the moon at 180°, not the moon somewhere between 180°
/// and 225°.
MoonPhase moonPhaseOf(double elongationDegrees) {
  final double e = norm360(elongationDegrees);
  final int octant = ((e + 22.5) / 45).floor() % 8;
  return MoonPhase.values[octant];
}

/// How much of the moon's face is lit, 0 at the new moon and 1 at the full.
double moonIlluminationOf(double elongationDegrees) =>
    (1 - math.cos(elongationDegrees * math.pi / 180)) / 2;

/// Whether the moon is waxing or waning.
enum Paksha {
  shukla,
  krishna;

  String get label => this == Paksha.shukla ? 'Shukla' : 'Krishna';
  String get labelNe => this == Paksha.shukla ? 'शुक्ल पक्ष' : 'कृष्ण पक्ष';

  /// The waxing half is bright, the waning half dark.
  String get glossEn =>
      this == Paksha.shukla ? 'waxing, bright half' : 'waning, dark half';
}

/// A whole day's almanac.
class Panchang {
  const Panchang({
    required this.date,
    required this.tithi,
    required this.paksha,
    required this.nakshatra,
    required this.yoga,
    required this.karana,
    required this.moonSidereal,
    required this.sunSidereal,
    required this.moonPhase,
    required this.moonIllumination,
    required this.lunarMonthIndex,
    required this.lunarMonthEn,
    required this.lunarMonthNe,
    required this.isAdhikMasa,
    required this.sunrise,
    required this.sunset,
    required this.moonrise,
    required this.moonset,
  });

  final DateTime date;
  final PanchangElement tithi;
  final Paksha paksha;
  final PanchangElement nakshatra;
  final PanchangElement yoga;
  final PanchangElement karana;

  /// The moon's and the sun's sidereal longitudes at sunrise, in degrees.
  /// Everything else here is derived from these two numbers, so exposing them
  /// lets callers cut the sky up their own way — into rashis, say, rather than
  /// nakshatras.
  final double moonSidereal;
  final double sunSidereal;

  /// The shape of the moon, and how much of its face is lit.
  final MoonPhase moonPhase;
  final double moonIllumination;

  /// The amanta lunar month, 1 = Chaitra. Nepal *names* its fasts by the
  /// purnimanta month instead, which differs in the dark half — see
  /// `religious_days.dart`.
  final int lunarMonthIndex;

  final String lunarMonthEn;
  final String lunarMonthNe;

  /// True in a leap month — one that begins and ends with the sun in the same
  /// sign, so its name is repeated and prefixed "Adhik".
  final bool isAdhikMasa;

  /// All in Nepal time. The moon may fail to rise or set on a given day, so
  /// those two are nullable; the sun, at Kathmandu's latitude, never does.
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime? moonrise;
  final DateTime? moonset;

  String lunarMonth({required bool nepali}) {
    final String name = nepali ? lunarMonthNe : lunarMonthEn;
    if (!isAdhikMasa) {
      return name;
    }
    return nepali ? 'अधिक $name' : 'Adhik $name';
  }

  @override
  String toString() =>
      'Panchang(${dayKey(date)}, ${tithi.nameEn}, ${nakshatra.nameEn})';
}

/// The signed angle from [from] to [to], in (-180, 180].
double _angleTo(double from, double to) {
  double d = (to - from) % 360;
  if (d > 180) {
    d -= 360;
  }
  if (d <= -180) {
    d += 360;
  }
  return d;
}

/// The Julian Day at which [longitude] next reaches [target] degrees, starting
/// from [jd]. [rate] is roughly how fast the angle moves, in degrees per day.
double _nextCrossing(
  double Function(double jd) longitude,
  double target,
  double jd,
  double rate,
) {
  // Step forward until the signed gap to the target flips from negative to
  // positive, then bisect. The window is far shorter than a half-turn, so the
  // signed gap cannot wrap around and fool us.
  const double step = 0.05;
  final double maxDays = 400 / rate;
  double lo = jd;
  double previous = _angleTo(longitude(lo), target);
  for (double t = jd + step; t <= jd + maxDays; t += step) {
    final double gap = _angleTo(longitude(t), target);
    if (previous <= 0 && gap > 0) {
      double a = lo;
      double b = t;
      for (int i = 0; i < 30; i++) {
        final double mid = (a + b) / 2;
        if (_angleTo(longitude(mid), target) <= 0) {
          a = mid;
        } else {
          b = mid;
        }
      }
      return (a + b) / 2;
    }
    previous = gap;
    lo = t;
  }
  return jd + maxDays;
}

/// The moon's angular distance ahead of the sun — the one angle that tithi,
/// paksha and karana are all read from.
double elongation(double jd) =>
    norm360(moonPosition(jd).longitude - sunLongitude(jd));

/// The Julian Day of the new moon at or before [jd].
double newMoonBefore(double jd) {
  // The elongation is how far past the new moon we already are, and it grows
  // by about 12.19° a day, so this lands within an hour or so on the first
  // guess; the iteration then closes it.
  double guess = jd - elongation(jd) / 12.19;
  for (int i = 0; i < 6; i++) {
    guess -= _angleTo(0, elongation(guess)) / 12.19;
  }
  return guess;
}

/// Which of the twelve signs the sun is in, 0-based.
int _sunRasi(double jd) => (sunSidereal(jd) / 30).floor() % 12;

/// Panchangs already worked out, keyed by day and place.
///
/// A day's panchang costs a few hundred trigonometric terms plus a scan for
/// sunrise, which is nothing once — and quite a lot sixty times a second. The
/// hover card is rebuilt on every mouse-move, and several cards on the page ask
/// for the same day at once, so the answer is worth keeping.
///
/// Bounded, because a reader scrolling through years would otherwise grow it
/// without limit. Panchangs do not change, so eviction is arbitrary: the oldest
/// insertion goes.
final Map<String, Panchang> _cache = <String, Panchang>{};
const int _cacheLimit = 512;

/// The whole panchang for the Gregorian day [date], reckoned at Kathmandu.
///
/// Every element is the one in force at sunrise, which is how a patro names
/// its days.
///
/// This is a *Nepali* almanac and it is built like one. The day it scans runs
/// from midnight Nepal time, and every time it hands back is in Nepal time. The
/// [latitude] and [longitude] are there to move about within Nepal — the far
/// west sees the sun a few minutes after Kathmandu — and not to compute a
/// panchang for Oslo. Push them far enough and the twenty-four hours being
/// searched stop lining up with that place's own day, and you can get a sunset
/// before the sunrise. Guarding against it would mean re-anchoring the scan,
/// which would disturb behaviour checked against Hamro Patro for all 33 days of
/// a month; the honest thing is to say what this function is for.
Panchang panchangFor(
  DateTime date, {
  double latitude = kKathmanduLatitude,
  double longitude = kKathmanduLongitude,
}) {
  final String key = '${dayKey(date)}@$latitude,$longitude';
  final Panchang? hit = _cache[key];
  if (hit != null) {
    return hit;
  }
  final Panchang computed = _computePanchang(date, latitude, longitude);
  if (_cache.length >= _cacheLimit) {
    _cache.remove(_cache.keys.first);
  }
  _cache[key] = computed;
  return computed;
}

Panchang _computePanchang(DateTime date, double latitude, double longitude) {
  // Nepal time is UTC+05:45, so the local day starts 5h45m before UTC midnight.
  final DateTime localMidnightUtc = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).subtract(kNepalOffset);

  final RiseSet sun = sunRiseSet(localMidnightUtc, latitude, longitude);
  final RiseSet moon = moonRiseSet(localMidnightUtc, latitude, longitude);
  // The sun always rises at this latitude; the fallback keeps the type honest.
  final DateTime sunriseUtc =
      sun.rise ?? localMidnightUtc.add(const Duration(hours: 6));
  final double jd = julianDay(sunriseUtc);

  // Tithi: 12° of elongation each, thirty to a lunar month.
  final double elong = elongation(jd);
  final int tithiIndex = (elong / 12).floor() + 1;
  final Paksha paksha = tithiIndex <= 15 ? Paksha.shukla : Paksha.krishna;
  final int withinPaksha = tithiIndex <= 15 ? tithiIndex : tithiIndex - 15;
  final String tithiEn = tithiIndex == 15
      ? 'Purnima'
      : tithiIndex == 30
      ? 'Amavasya'
      : _tithiEn[withinPaksha - 1];
  final String tithiNe = tithiIndex == 15
      ? 'पूर्णिमा'
      : tithiIndex == 30
      ? 'औंसी'
      : _tithiNe[withinPaksha - 1];

  // Nakshatra: 27 of 13°20' each, against the fixed stars.
  const double nakshatraWidth = 360 / 27;
  final int nakshatraIndex = (moonSidereal(jd) / nakshatraWidth).floor() + 1;

  // Yoga: the two longitudes added, in the same 13°20' steps.
  double yogaAngle(double t) => norm360(sunSidereal(t) + moonSidereal(t));
  final int yogaIndex = (yogaAngle(jd) / nakshatraWidth).floor() + 1;

  // Karana: half a tithi, sixty to a month. The first and last three are
  // fixed; the seven in between repeat eight times.
  final int karanaIndex = (elong / 6).floor() + 1;
  final String karanaEn;
  final String karanaNe;
  if (karanaIndex == 1) {
    karanaEn = _fixedKaranaEn[0];
    karanaNe = _fixedKaranaNe[0];
  } else if (karanaIndex >= 58) {
    karanaEn = _fixedKaranaEn[karanaIndex - 57];
    karanaNe = _fixedKaranaNe[karanaIndex - 57];
  } else {
    karanaEn = _movableKaranaEn[(karanaIndex - 2) % 7];
    karanaNe = _movableKaranaNe[(karanaIndex - 2) % 7];
  }

  // The lunar month takes its name from the sign the sun stood in at the new
  // moon that began it. When the next new moon finds the sun in that same
  // sign — because the sun did not manage to cross a boundary in one whole
  // lunation — the month is a leap month, and repeats.
  final double thisNewMoon = newMoonBefore(jd);
  final double nextNewMoon = newMoonBefore(thisNewMoon + 35);
  final int rasiAtStart = _sunRasi(thisNewMoon);
  final bool adhik = rasiAtStart == _sunRasi(nextNewMoon);
  final int lunarMonthIndex = (rasiAtStart + 1) % 12;

  DateTime nepal(double j) => nepalTimeOf(dateTimeOfJd(j));

  return Panchang(
    date: dateOnly(date),
    tithi: PanchangElement(
      index: tithiIndex,
      nameEn: tithiEn,
      nameNe: tithiNe,
      endsAt: nepal(
        _nextCrossing(elongation, (tithiIndex * 12) % 360, jd, 12.19),
      ),
    ),
    paksha: paksha,
    nakshatra: PanchangElement(
      index: nakshatraIndex,
      nameEn: _nakshatraEn[nakshatraIndex - 1],
      nameNe: _nakshatraNe[nakshatraIndex - 1],
      endsAt: nepal(
        _nextCrossing(
          moonSidereal,
          (nakshatraIndex * nakshatraWidth) % 360,
          jd,
          13.18,
        ),
      ),
    ),
    yoga: PanchangElement(
      index: yogaIndex,
      nameEn: _yogaEn[yogaIndex - 1],
      nameNe: _yogaNe[yogaIndex - 1],
      endsAt: nepal(
        _nextCrossing(yogaAngle, (yogaIndex * nakshatraWidth) % 360, jd, 14.16),
      ),
    ),
    karana: PanchangElement(
      index: karanaIndex,
      nameEn: karanaEn,
      nameNe: karanaNe,
      endsAt: nepal(
        _nextCrossing(elongation, (karanaIndex * 6) % 360, jd, 12.19),
      ),
    ),
    moonSidereal: moonSidereal(jd),
    sunSidereal: sunSidereal(jd),
    moonPhase: moonPhaseOf(elong),
    moonIllumination: moonIlluminationOf(elong),
    lunarMonthIndex: lunarMonthIndex + 1,
    lunarMonthEn: _lunarMonthEn[lunarMonthIndex],
    lunarMonthNe: _lunarMonthNe[lunarMonthIndex],
    isAdhikMasa: adhik,
    sunrise: nepalTimeOf(sunriseUtc),
    sunset: nepalTimeOf(sun.set ?? sunriseUtc),
    moonrise: moon.rise == null ? null : nepalTimeOf(moon.rise!),
    moonset: moon.set == null ? null : nepalTimeOf(moon.set!),
  );
}
