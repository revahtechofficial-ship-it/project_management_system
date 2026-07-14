import 'package:flutter/material.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/nepali_calendar.dart';
import '../../../core/utils/panchang.dart';
import '../../../core/utils/religious_days.dart';
import '../../../data/models/holiday.dart';
import '../providers/patro_providers.dart';

/// What a day looks like when you click it: both dates, the festival, whether
/// the office is shut, the tithi, sunrise, sunset, the moon.
///
/// Every line here is computed on the spot — the panchang for a single day is
/// a few dozen trigonometric terms, which is nothing next to a frame budget. So
/// opening it costs no round trip and the card is complete the instant it
/// appears.
class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.date,
    required this.nepali,
    required this.events,
    required this.onViewDetails,
    required this.onAddNote,
    required this.onSetReminder,
  });

  static const double width = 300;

  final DateTime date;
  final bool nepali;
  final List<CalendarEvent> events;

  final VoidCallback onViewDetails;
  final VoidCallback onAddNote;
  final VoidCallback onSetReminder;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BsDate bs = adToBs(date);
    final int column = sundayFirstIndex(date);
    final Panchang p = panchangFor(date);
    final CalendarEvent? festival = cellHoliday(events);
    final Holiday? holiday = festival?.holiday;
    final List<ReligiousDay> religious = religiousDaysFor(date);

    // A day is a holiday, a weekend, or a working day — and saying which is the
    // single most useful line on this card.
    final (String, String, Color) status = switch (holiday) {
      final Holiday h when h.isPublic => (
        'Public holiday',
        'सार्वजनिक बिदा',
        scheme.error,
      ),
      final Holiday _ => ('Observance', 'पर्व', scheme.tertiary),
      _ when isWeekend(date) => ('Weekend', 'साप्ताहिक बिदा', scheme.error),
      _ => ('Working day', 'कार्य दिन', scheme.onSurfaceVariant),
    };

    return Material(
      elevation: 10,
      color: scheme.surface,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The Nepali date leads, big, because that is what the reader came
            // for; the Gregorian one follows underneath.
            Text(
              '${toNepaliDigits(bs.day)} ${kBsMonthsNe[bs.month]} '
              '${toNepaliDigits(bs.year)}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 1),
            Text(
              '${kBsMonthsEn[bs.month]} ${bs.day}, ${bs.year}',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            // The weekday holds its ground and the date yields, because a card
            // 300px wide has to survive a long Nepali weekday and a reader who
            // has turned their text size up.
            Row(
              children: <Widget>[
                Text(
                  nepali ? kWeekdaysNeLong[column] : kWeekdaysEnLong[column],
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isWeekend(date) ? scheme.error : scheme.onSurface,
                  ),
                ),
                Flexible(
                  child: Text(
                    '  ·  ${formatLongDate(date).split(', ').last}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            if (festival != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                festival.name(nepali: nepali),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.error,
                ),
              ),
            ],

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: status.$3.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                nepali ? status.$2 : status.$1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: status.$3,
                ),
              ),
            ),

            const Divider(height: 16),

            _Row(
              icon: Icons.brightness_3_outlined,
              label: nepali ? 'तिथि' : 'Tithi',
              value:
                  '${p.tithi.name(nepali: nepali)} · '
                  '${nepali ? p.paksha.labelNe : p.paksha.label}',
            ),
            if (religious.isNotEmpty)
              _Row(
                icon: Icons.temple_hindu_outlined,
                label: nepali ? 'व्रत' : 'Brata',
                value: religious
                    .map((ReligiousDay d) => d.name(nepali: nepali))
                    .join(' · '),
              ),
            _Row(
              icon: Icons.wb_sunny_outlined,
              label: nepali ? 'सूर्योदय' : 'Sunrise',
              value: formatClock(p.sunrise, nepali: nepali),
            ),
            _Row(
              icon: Icons.wb_twilight_outlined,
              label: nepali ? 'सूर्यास्त' : 'Sunset',
              value: formatClock(p.sunset, nepali: nepali),
            ),
            _Row(
              icon: Icons.nightlight_outlined,
              label: nepali ? 'चन्द्रकला' : 'Moon',
              value:
                  '${p.moonPhase.symbol} '
                  '${p.moonPhase.phaseName(nepali: nepali)} · '
                  '${localDigits((p.moonIllumination * 100).round(), nepali: nepali)}%',
            ),

            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Action(
                    icon: Icons.open_in_new,
                    label: nepali ? 'विवरण' : 'Details',
                    onTap: onViewDetails,
                    filled: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _Action(
                    icon: Icons.note_add_outlined,
                    label: nepali ? 'नोट' : 'Note',
                    onTap: onAddNote,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _Action(
                    icon: Icons.notifications_outlined,
                    label: nepali ? 'सम्झना' : 'Remind',
                    onTap: onSetReminder,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 7),
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: filled
          ? scheme.primary
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 14,
                color: filled ? scheme.onPrimary : scheme.onSurface,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: filled ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
