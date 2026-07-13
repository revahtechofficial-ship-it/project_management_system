import 'dart:math' as math;

// Solar and lunar positions, and rise/set times (AGENTS.md §1 `core/utils`).
//
// Pure Dart, from Meeus, *Astronomical Algorithms* (2nd ed.): the sun from
// chapter 25 and the moon from the truncated ELP2000-82 series of chapter 47.
// No ephemeris files and no FFI, so this works unchanged on the web.
//
// The truncated series gives the moon's longitude to about 10 arcseconds and
// the sun's to about 1 arcsecond. Panchang divides the sky into units no
// finer than 6° (a karana), so that is four orders of magnitude more precision
// than the answer needs — the error only matters within a few seconds of an
// element's boundary.

const double _deg = math.pi / 180;

double _sin(double degrees) => math.sin(degrees * _deg);
double _cos(double degrees) => math.cos(degrees * _deg);

/// Wraps an angle into [0, 360).
double norm360(double degrees) {
  final double d = degrees % 360;
  return d < 0 ? d + 360 : d;
}

/// The Julian Day of an instant, which must be UTC.
double julianDay(DateTime utc) {
  final DateTime t = utc.toUtc();
  int year = t.year;
  int month = t.month;
  final double day =
      t.day +
      (t.hour + (t.minute + (t.second + t.millisecond / 1000) / 60) / 60) / 24;
  if (month <= 2) {
    year -= 1;
    month += 12;
  }
  final int a = (year / 100).floor();
  final int b = 2 - a + (a / 4).floor();
  return (365.25 * (year + 4716)).floor() +
      (30.6001 * (month + 1)).floor() +
      day +
      b -
      1524.5;
}

/// The instant of a Julian Day, in UTC.
DateTime dateTimeOfJd(double jd) {
  final int ms = ((jd - 2440587.5) * 86400000).round();
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

/// Julian centuries from J2000.0.
double julianCentury(double jd) => (jd - 2451545.0) / 36525;

/// The sun's apparent geocentric ecliptic longitude, in degrees (Meeus 25).
double sunLongitude(double jd) {
  final double t = julianCentury(jd);
  final double l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
  final double m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t;
  final double c =
      (1.914602 - 0.004817 * t - 0.000014 * t * t) * _sin(m) +
      (0.019993 - 0.000101 * t) * _sin(2 * m) +
      0.000289 * _sin(3 * m);
  final double trueLong = l0 + c;
  final double omega = 125.04 - 1934.136 * t;
  return norm360(trueLong - 0.00569 - 0.00478 * _sin(omega));
}

/// Where the moon is: ecliptic longitude and latitude in degrees, and distance
/// from the Earth's centre in kilometres.
class MoonPosition {
  const MoonPosition(this.longitude, this.latitude, this.distanceKm);

  final double longitude;
  final double latitude;
  final double distanceKm;

  /// The moon's equatorial horizontal parallax, in degrees.
  double get parallax => math.asin(6378.14 / distanceKm) / _deg;

  @override
  String toString() => 'MoonPosition($longitude, $latitude, ${distanceKm}km)';
}

// Meeus table 47.A — periodic terms for the moon's longitude (sigma-l, in
// units of 1e-6 degrees) and distance (sigma-r, in units of 1e-3 km).
// Columns: D, M, M', F, sigma-l, sigma-r.
const List<List<int>> _lrTerms = <List<int>>[
  <int>[0, 0, 1, 0, 6288774, -20905355],
  <int>[2, 0, -1, 0, 1274027, -3699111],
  <int>[2, 0, 0, 0, 658314, -2955968],
  <int>[0, 0, 2, 0, 213618, -569925],
  <int>[0, 1, 0, 0, -185116, 48888],
  <int>[0, 0, 0, 2, -114332, -3149],
  <int>[2, 0, -2, 0, 58793, 246158],
  <int>[2, -1, -1, 0, 57066, -152138],
  <int>[2, 0, 1, 0, 53322, -170733],
  <int>[2, -1, 0, 0, 45758, -204586],
  <int>[0, 1, -1, 0, -40923, -129620],
  <int>[1, 0, 0, 0, -34720, 108743],
  <int>[0, 1, 1, 0, -30383, 104755],
  <int>[2, 0, 0, -2, 15327, 10321],
  <int>[0, 0, 1, 2, -12528, 0],
  <int>[0, 0, 1, -2, 10980, 79661],
  <int>[4, 0, -1, 0, 10675, -34782],
  <int>[0, 0, 3, 0, 10034, -23210],
  <int>[4, 0, -2, 0, 8548, -21636],
  <int>[2, 1, -1, 0, -7888, 24208],
  <int>[2, 1, 0, 0, -6766, 30824],
  <int>[1, 0, -1, 0, -5163, -8379],
  <int>[1, 1, 0, 0, 4987, -16675],
  <int>[2, -1, 1, 0, 4036, -12831],
  <int>[2, 0, 2, 0, 3994, -10445],
  <int>[4, 0, 0, 0, 3861, -11650],
  <int>[2, 0, -3, 0, 3665, 14403],
  <int>[0, 1, -2, 0, -2689, -7003],
  <int>[2, 0, -1, 2, -2602, 0],
  <int>[2, -1, -2, 0, 2390, 10056],
  <int>[1, 0, 1, 0, -2348, 6322],
  <int>[2, -2, 0, 0, 2236, -9884],
  <int>[0, 1, 2, 0, -2120, 5751],
  <int>[0, 2, 0, 0, -2069, 0],
  <int>[2, -2, -1, 0, 2048, -4950],
  <int>[2, 0, 1, -2, -1773, 4130],
  <int>[2, 0, 0, 2, -1595, 0],
  <int>[4, -1, -1, 0, 1215, -3958],
  <int>[0, 0, 2, 2, -1110, 0],
  <int>[3, 0, -1, 0, -892, 3258],
  <int>[2, 1, 1, 0, -810, 2616],
  <int>[4, -1, -2, 0, 759, -1897],
  <int>[0, 2, -1, 0, -713, -2117],
  <int>[2, 2, -1, 0, -700, 2354],
  <int>[2, 1, -2, 0, 691, 0],
  <int>[2, -1, 0, -2, 596, 0],
  <int>[4, 0, 1, 0, 549, -1423],
  <int>[0, 0, 4, 0, 537, -1117],
  <int>[4, -1, 0, 0, 520, -1571],
  <int>[1, 0, -2, 0, -487, -1739],
  <int>[2, 1, 0, -2, -399, 0],
  <int>[0, 0, 2, -2, -381, -4421],
  <int>[1, 1, 1, 0, 351, 0],
  <int>[3, 0, -2, 0, -340, 0],
  <int>[4, 0, -3, 0, 330, 0],
  <int>[2, -1, 2, 0, 327, 0],
  <int>[0, 2, 1, 0, -323, 1165],
  <int>[1, 1, -1, 0, 299, 0],
  <int>[2, 0, 3, 0, 294, 0],
  <int>[2, 0, -1, -2, 0, 8752],
];

// Meeus table 47.B — periodic terms for the moon's latitude (sigma-b, in units
// of 1e-6 degrees). Columns: D, M, M', F, sigma-b.
const List<List<int>> _bTerms = <List<int>>[
  <int>[0, 0, 0, 1, 5128122],
  <int>[0, 0, 1, 1, 280602],
  <int>[0, 0, 1, -1, 277693],
  <int>[2, 0, 0, -1, 173237],
  <int>[2, 0, -1, 1, 55413],
  <int>[2, 0, -1, -1, 46271],
  <int>[2, 0, 0, 1, 32573],
  <int>[0, 0, 2, 1, 17198],
  <int>[2, 0, 1, -1, 9266],
  <int>[0, 0, 2, -1, 8822],
  <int>[2, -1, 0, -1, 8216],
  <int>[2, 0, -2, -1, 4324],
  <int>[2, 0, 1, 1, 4200],
  <int>[2, 1, 0, -1, -3359],
  <int>[2, -1, -1, 1, 2463],
  <int>[2, -1, 0, 1, 2211],
  <int>[2, -1, -1, -1, 2065],
  <int>[0, 1, -1, -1, -1870],
  <int>[4, 0, -1, -1, 1828],
  <int>[0, 1, 0, 1, -1794],
  <int>[0, 0, 0, 3, -1749],
  <int>[0, 1, -1, 1, -1565],
  <int>[1, 0, 0, 1, -1491],
  <int>[0, 1, 1, 1, -1475],
  <int>[0, 1, 1, -1, -1410],
  <int>[0, 1, 0, -1, -1344],
  <int>[1, 0, 0, -1, -1335],
  <int>[0, 0, 3, 1, 1107],
  <int>[4, 0, 0, -1, 1021],
  <int>[4, 0, -1, 1, 833],
  <int>[0, 0, 1, -3, 777],
  <int>[4, 0, -2, 1, 671],
  <int>[2, 0, 0, -3, 607],
  <int>[2, 0, 2, -1, 596],
  <int>[2, -1, 1, -1, 491],
  <int>[2, 0, -2, 1, -451],
  <int>[0, 0, 3, -1, 439],
  <int>[2, 0, 2, 1, 422],
  <int>[2, 0, -3, -1, 421],
  <int>[2, 1, -1, 1, -366],
  <int>[2, 1, 0, 1, -351],
  <int>[4, 0, 0, 1, 331],
  <int>[2, -1, 1, 1, 315],
  <int>[2, -2, 0, -1, 302],
  <int>[0, 0, 1, 3, -283],
  <int>[2, 1, 1, -1, -229],
  <int>[1, 1, 0, -1, 223],
  <int>[1, 1, 0, 1, 223],
  <int>[0, 1, -2, -1, -220],
  <int>[2, 1, -1, -1, -220],
  <int>[1, 0, 1, 1, -185],
  <int>[2, -1, -2, -1, 181],
  <int>[0, 1, 2, 1, -177],
  <int>[4, 0, -2, -1, 176],
  <int>[4, -1, -1, -1, 166],
  <int>[1, 0, 1, -1, -164],
  <int>[4, 0, 1, -1, 132],
  <int>[1, 0, -1, -1, -119],
  <int>[4, -1, 0, -1, 115],
  <int>[2, -2, 0, 1, 107],
];

/// The moon's geocentric position (Meeus 47).
MoonPosition moonPosition(double jd) {
  final double t = julianCentury(jd);
  final double t2 = t * t;
  final double t3 = t2 * t;
  final double t4 = t3 * t;

  // Moon's mean longitude, mean elongation, the sun's mean anomaly, the moon's
  // mean anomaly, and the moon's argument of latitude.
  final double lp = norm360(
    218.3164477 +
        481267.88123421 * t -
        0.0015786 * t2 +
        t3 / 538841 -
        t4 / 65194000,
  );
  final double d = norm360(
    297.8501921 +
        445267.1114034 * t -
        0.0018819 * t2 +
        t3 / 545868 -
        t4 / 113065000,
  );
  final double m = norm360(
    357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000,
  );
  final double mp = norm360(
    134.9633964 +
        477198.8675055 * t +
        0.0087414 * t2 +
        t3 / 69699 -
        t4 / 14712000,
  );
  final double f = norm360(
    93.2720950 +
        483202.0175233 * t -
        0.0036539 * t2 -
        t3 / 3526000 +
        t4 / 863310000,
  );

  final double a1 = norm360(119.75 + 131.849 * t);
  final double a2 = norm360(53.09 + 479264.290 * t);
  final double a3 = norm360(313.45 + 481266.484 * t);

  // The sun's orbit is slowly changing shape, which modulates the terms that
  // depend on its anomaly.
  final double e = 1 - 0.002516 * t - 0.0000074 * t2;

  double sumL = 0;
  double sumR = 0;
  for (final List<int> term in _lrTerms) {
    final double arg = term[0] * d + term[1] * m + term[2] * mp + term[3] * f;
    final double ecc = math.pow(e, term[1].abs()).toDouble();
    sumL += term[4] * ecc * _sin(arg);
    sumR += term[5] * ecc * _cos(arg);
  }
  double sumB = 0;
  for (final List<int> term in _bTerms) {
    final double arg = term[0] * d + term[1] * m + term[2] * mp + term[3] * f;
    final double ecc = math.pow(e, term[1].abs()).toDouble();
    sumB += term[4] * ecc * _sin(arg);
  }

  // Additive corrections for Venus (A1), Jupiter (A2), and the flattening of
  // the Earth (A3).
  sumL += 3958 * _sin(a1) + 1962 * _sin(lp - f) + 318 * _sin(a2);
  sumB +=
      -2235 * _sin(lp) +
      382 * _sin(a3) +
      175 * _sin(a1 - f) +
      175 * _sin(a1 + f) +
      127 * _sin(lp - mp) -
      115 * _sin(lp + mp);

  return MoonPosition(
    norm360(lp + sumL / 1000000),
    sumB / 1000000,
    385000.56 + sumR / 1000,
  );
}

/// The mean obliquity of the ecliptic, in degrees.
double obliquity(double jd) {
  final double t = julianCentury(jd);
  return 23.439291 - 0.0130042 * t - 1.64e-7 * t * t + 5.04e-7 * t * t * t;
}

/// Greenwich mean sidereal time, in degrees.
double siderealTime(double jd) {
  final double t = julianCentury(jd);
  return norm360(
    280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        0.000387933 * t * t -
        t * t * t / 38710000,
  );
}

/// A body's altitude above the horizon, in degrees, seen from a place.
///
/// [latitude] and [longitude] are in degrees, longitude positive east.
double _altitude(
  double lambda,
  double beta,
  double jd,
  double latitude,
  double longitude,
) {
  final double eps = obliquity(jd);
  final double ra = math.atan2(
    _sin(lambda) * _cos(eps) - math.tan(beta * _deg) * _sin(eps),
    _cos(lambda),
  );
  final double dec = math.asin(
    _sin(beta) * _cos(eps) + _cos(beta) * _sin(eps) * _sin(lambda),
  );
  final double h = (siderealTime(jd) + longitude) * _deg - ra;
  return math.asin(
        _sin(latitude) * math.sin(dec) +
            _cos(latitude) * math.cos(dec) * math.cos(h),
      ) /
      _deg;
}

/// The sun's altitude above the horizon, in degrees.
double sunAltitude(double jd, double latitude, double longitude) =>
    _altitude(sunLongitude(jd), 0, jd, latitude, longitude);

/// The moon's altitude above the horizon, in degrees.
double moonAltitude(double jd, double latitude, double longitude) {
  final MoonPosition moon = moonPosition(jd);
  return _altitude(moon.longitude, moon.latitude, jd, latitude, longitude);
}

/// A rise and a set, either of which may be absent — the moon genuinely fails
/// to rise on about one day in thirty, and in the far north the sun can do the
/// same for months.
class RiseSet {
  const RiseSet({this.rise, this.set});

  final DateTime? rise;
  final DateTime? set;

  @override
  String toString() => 'RiseSet(rise: $rise, set: $set)';
}

/// The standard altitude at which the sun is said to rise or set: its upper
/// limb on the horizon, allowing for refraction.
const double _sunHorizon = -0.833;

/// Finds when [altitudeAt] crosses [horizon] during the 24 hours from [start].
///
/// Scans in ten-minute steps and bisects each crossing to the second. Slower
/// than Meeus's closed form, but it handles the moon — whose horizon shifts
/// with its distance, and which some days does not rise at all — without any
/// special cases.
RiseSet _findRiseSet(
  DateTime start,
  double latitude,
  double longitude,
  double Function(double jd) altitudeAt,
  double Function(double jd) horizonAt,
) {
  const int stepMinutes = 10;
  const int steps = 24 * 60 ~/ stepMinutes;
  final double jd0 = julianDay(start);
  const double stepDays = stepMinutes / (24 * 60);

  double f(double jd) => altitudeAt(jd) - horizonAt(jd);

  DateTime? rise;
  DateTime? set;
  double previous = f(jd0);

  for (int i = 1; i <= steps; i++) {
    final double jd = jd0 + i * stepDays;
    final double current = f(jd);
    if (previous.sign != current.sign) {
      // Bisect the ten-minute window down to a second.
      double lo = jd - stepDays;
      double hi = jd;
      final double loValue = previous;
      for (int k = 0; k < 24; k++) {
        final double mid = (lo + hi) / 2;
        if (f(mid).sign == loValue.sign) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      final DateTime when = dateTimeOfJd((lo + hi) / 2);
      if (current > previous) {
        rise ??= when;
      } else {
        set ??= when;
      }
    }
    previous = current;
  }
  return RiseSet(rise: rise, set: set);
}

/// When the sun rises and sets, as UTC instants.
///
/// [start] is the instant local midnight begins, in UTC.
RiseSet sunRiseSet(DateTime start, double latitude, double longitude) =>
    _findRiseSet(
      start,
      latitude,
      longitude,
      (double jd) => sunAltitude(jd, latitude, longitude),
      (double _) => _sunHorizon,
    );

/// When the moon rises and sets, as UTC instants; either may be null.
///
/// The moon's horizon is not a constant: it is close enough to be shifted by
/// its own parallax, which varies by a tenth of a degree over its orbit — a
/// few minutes of rise time.
RiseSet moonRiseSet(DateTime start, double latitude, double longitude) =>
    _findRiseSet(
      start,
      latitude,
      longitude,
      (double jd) => moonAltitude(jd, latitude, longitude),
      (double jd) => 0.7275 * moonPosition(jd).parallax - 0.5666,
    );

/// The Lahiri (Chitrapaksha) ayanamsa in degrees — the angle between the
/// tropical zodiac the formulae above compute and the sidereal zodiac that
/// panchang counts nakshatras in.
///
/// Anchored the way Swiss Ephemeris anchors it: 22.460148° at the start of
/// 1900, carried forward by general precession.
double ayanamsa(double jd) {
  final double t = julianCentury(jd);
  double precession(double c) =>
      5028.796195 * c + 1.1054348 * c * c + 0.00007964 * c * c * c;
  return 22.460148 + (precession(t) - precession(-1)) / 3600;
}

/// The sun's sidereal (nirayana) longitude, in degrees.
double sunSidereal(double jd) => norm360(sunLongitude(jd) - ayanamsa(jd));

/// The moon's sidereal (nirayana) longitude, in degrees.
double moonSidereal(double jd) =>
    norm360(moonPosition(jd).longitude - ayanamsa(jd));
