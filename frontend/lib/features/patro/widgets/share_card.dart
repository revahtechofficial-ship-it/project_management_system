import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/nepali_calendar.dart';
import '../../../core/utils/religious_days.dart';
import '../providers/patro_providers.dart';

/// What a shared card is for.
enum ShareStyle {
  date,
  festival,
  greeting;

  String get label => switch (this) {
    ShareStyle.date => 'Date card',
    ShareStyle.festival => 'Festival card',
    ShareStyle.greeting => 'Greeting card',
  };

  String get labelNe => switch (this) {
    ShareStyle.date => 'मिति कार्ड',
    ShareStyle.festival => 'पर्व कार्ड',
    ShareStyle.greeting => 'शुभकामना कार्ड',
  };
}

/// The card that gets rendered to a PNG.
///
/// Deliberately fixed at 600x600 rather than sized to the screen: it is going
/// to be shared, and a card that came out a different size on every laptop
/// would be no use to anyone. Everything on it is laid out for that box.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.date,
    required this.nepali,
    required this.style,
    required this.events,
  });

  static const double side = 600;

  final DateTime date;
  final bool nepali;
  final ShareStyle style;
  final List<CalendarEvent> events;

  /// The holiday to lead with, if any.
  CalendarEvent? get _festival => cellHoliday(events);

  @override
  Widget build(BuildContext context) {
    final BsDate bs = adToBs(date);
    final int column = sundayFirstIndex(date);
    final CalendarEvent? festival = _festival;

    // A greeting or a festival card has to have a festival. Falling back to
    // the plain date card is better than a card that says "null".
    final ShareStyle effective = (festival == null && style != ShareStyle.date)
        ? ShareStyle.date
        : style;

    final List<ReligiousDay> religious = religiousDaysFor(date);

    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        gradient: switch (effective) {
          ShareStyle.greeting => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFB91C1C), Color(0xFFF59E0B)],
          ),
          ShareStyle.festival => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF7C2D12), Color(0xFFE11D48)],
          ),
          ShareStyle.date => AppColors.brandGradient,
        },
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.calendar_month_outlined,
                color: Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                nepali ? 'पात्रो' : 'Patro',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                kWeekdaysNeLong[column],
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
          const Spacer(),

          if (effective == ShareStyle.greeting) ...<Widget>[
            Text(
              nepali ? 'शुभकामना' : 'Best wishes',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // The big number: the BS day, because that is the one a Nepali reader
          // looks for first.
          Text(
            localDigits(bs.day, nepali: true),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 108,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${kBsMonthsNe[bs.month]} ${toNepaliDigits(bs.year)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${kBsMonthsEn[bs.month]} ${bs.day}, ${bs.year} · '
            '${formatLongDate(date)}',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),

          if (festival != null && effective != ShareStyle.date) ...<Widget>[
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                festival.name(nepali: nepali),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],

          const Spacer(),

          if (religious.isNotEmpty)
            Text(
              religious
                  .map((ReligiousDay d) => d.name(nepali: nepali))
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
        ],
      ),
    );
  }
}

/// The same day as plain text, for pasting into a message.
String shareText(
  DateTime date, {
  required bool nepali,
  required List<CalendarEvent> events,
}) {
  final BsDate bs = adToBs(date);
  final int column = sundayFirstIndex(date);
  final List<String> lines = <String>[
    '${kBsMonthsNe[bs.month]} ${toNepaliDigits(bs.day)}, '
        '${toNepaliDigits(bs.year)}  ·  ${kWeekdaysNeLong[column]}',
    '${kBsMonthsEn[bs.month]} ${bs.day}, ${bs.year}  ·  '
        '${formatLongDate(date)}',
  ];

  final CalendarEvent? festival = cellHoliday(events);
  if (festival != null) {
    lines.add('');
    lines.add('🎉 ${festival.name(nepali: nepali)}');
  }

  final List<ReligiousDay> religious = religiousDaysFor(date);
  if (religious.isNotEmpty) {
    lines.add(
      religious.map((ReligiousDay d) => d.name(nepali: nepali)).join(' · '),
    );
  }
  return lines.join('\n');
}
