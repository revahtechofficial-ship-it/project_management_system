import 'package:flutter/material.dart';

import '../../../core/utils/nepali_calendar.dart';
import '../../../core/utils/panchang.dart';

/// The day's almanac: the five limbs of the panchang, and the four times.
///
/// Every value is computed for Kathmandu from the sun's and the moon's
/// positions — nothing here comes from the server.
class PanchangCard extends StatelessWidget {
  const PanchangCard({super.key, required this.date, required this.nepali});

  final DateTime date;
  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Panchang p = panchangFor(date);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.brightness_3_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  nepali ? 'पञ्चाङ्ग' : 'Panchang',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  nepali ? 'काठमाडौं' : 'Kathmandu',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // The lunar month and the half it sits in frame everything else.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                _Chip(
                  label: p.lunarMonth(nepali: nepali),
                  color: scheme.primary,
                ),
                _Chip(
                  label: nepali ? p.paksha.labelNe : p.paksha.label,
                  color: p.paksha == Paksha.shukla
                      ? scheme.tertiary
                      : scheme.secondary,
                ),
              ],
            ),
            const Divider(height: 22),
            _Limb(
              label: nepali ? 'तिथि' : 'Tithi',
              element: p.tithi,
              nepali: nepali,
              on: p.date,
            ),
            _Limb(
              label: nepali ? 'नक्षत्र' : 'Nakshatra',
              element: p.nakshatra,
              nepali: nepali,
              on: p.date,
            ),
            _Limb(
              label: nepali ? 'योग' : 'Yoga',
              element: p.yoga,
              nepali: nepali,
              on: p.date,
            ),
            _Limb(
              label: nepali ? 'करण' : 'Karana',
              element: p.karana,
              nepali: nepali,
              on: p.date,
            ),
            const Divider(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Time(
                    icon: Icons.wb_sunny_outlined,
                    label: nepali ? 'सूर्योदय' : 'Sunrise',
                    time: p.sunrise,
                    nepali: nepali,
                  ),
                ),
                Expanded(
                  child: _Time(
                    icon: Icons.wb_twilight_outlined,
                    label: nepali ? 'सूर्यास्त' : 'Sunset',
                    time: p.sunset,
                    nepali: nepali,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Time(
                    icon: Icons.nightlight_outlined,
                    label: nepali ? 'चन्द्रोदय' : 'Moonrise',
                    time: p.moonrise,
                    nepali: nepali,
                  ),
                ),
                Expanded(
                  child: _Time(
                    icon: Icons.dark_mode_outlined,
                    label: nepali ? 'चन्द्रास्त' : 'Moonset',
                    time: p.moonset,
                    nepali: nepali,
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// One limb: its name, and the time it gives way to the next. A patro always
/// prints that time — a tithi is only "today's" until it ends.
class _Limb extends StatelessWidget {
  const _Limb({
    required this.label,
    required this.element,
    required this.nepali,
    required this.on,
  });

  final String label;
  final PanchangElement element;
  final bool nepali;

  /// The day being shown, so an element that runs past midnight can say so.
  final DateTime on;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool endsToday = isSameDay(element.endsAt, on);
    final String ends = formatClock(element.endsAt, nepali: nepali);
    final String until = endsToday
        ? (nepali ? '$ends सम्म' : 'till $ends')
        // Past midnight — say which day, or "till 2:14" reads as the past.
        : (nepali
              ? '$ends सम्म (${kWeekdaysNe[sundayFirstIndex(element.endsAt)]})'
              : 'till $ends '
                    '(${kWeekdaysEn[sundayFirstIndex(element.endsAt)]})');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  element.name(nepali: nepali),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  until,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time({
    required this.icon,
    required this.label,
    required this.time,
    required this.nepali,
  });

  final IconData icon;
  final String label;
  final DateTime? time;
  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                // The moon fails to rise, or to set, on about one day a month.
                // Saying so is better than showing a blank.
                time == null
                    ? (nepali ? '—' : '—')
                    : formatClock(time!, nepali: nepali),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
