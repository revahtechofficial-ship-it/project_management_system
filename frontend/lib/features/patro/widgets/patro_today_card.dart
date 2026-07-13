import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/nepali_calendar.dart';
import '../../../core/utils/panchang.dart';
import '../../../core/utils/religious_days.dart';
import '../../../data/enums/calendar_event_kind.dart';
import '../providers/patro_providers.dart';

/// Today's patro, on the dashboard: the Bikram Sambat date, whatever festival
/// falls today, and the tithi.
///
/// This is what a "home screen widget" can be here. A real one — the kind that
/// sits on an Android home screen — needs a native app, and this is a Flutter
/// web app; the browser has no such API. What it does have is the PWA, which
/// installs to the home screen already, and this card is what greets you when
/// you open it.
class PatroTodayCard extends ConsumerWidget {
  const PatroTodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime today = dateOnly(DateTime.now());
    final BsDate bs = adToBs(today);
    final int column = sundayFirstIndex(today);

    final Map<String, List<CalendarEvent>> events = ref.watch(
      calendarEventsProvider,
    );
    final List<CalendarEvent> todays =
        events[dayKey(today)] ?? const <CalendarEvent>[];
    final CalendarEvent? festival = cellHoliday(todays);
    final List<ReligiousDay> religious = religiousDaysFor(today);
    final Panchang p = panchangFor(today);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => context.go('/patro'),
        child: Row(
          children: <Widget>[
            // The date block, in the brand gradient. The BS day is the big
            // number because that is the one a Nepali reader looks for.
            Container(
              width: 116,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    kWeekdaysNe[column],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    toNepaliDigits(bs.day),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    kBsMonthsNe[bs.month],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    toNepaliDigits(bs.year),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      formatLongDate(today),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.tithi.nameEn} · ${p.paksha.label} · '
                      '${p.lunarMonth(nepali: false)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),

                    if (festival != null) ...<Widget>[
                      const SizedBox(height: 8),
                      _Chip(
                        icon: CalendarEventKind.holiday.icon,
                        label: festival.name(nepali: false),
                        color: scheme.error,
                      ),
                    ] else if (religious.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      _Chip(
                        icon: Icons.brightness_3_outlined,
                        label: religious.first.nameEn,
                        color: scheme.tertiary,
                      ),
                    ],

                    // What is on today besides the calendar itself.
                    if (todays.any(
                      (CalendarEvent e) => e.kind != CalendarEventKind.holiday,
                    )) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        _summarise(todays),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// "2 tasks due · 1 event" — counted by kind rather than listed, because the
  /// card has one line and a list would not fit in it.
  String _summarise(List<CalendarEvent> events) {
    final Map<CalendarEventKind, int> counts = <CalendarEventKind, int>{};
    for (final CalendarEvent e in events) {
      if (e.kind == CalendarEventKind.holiday) {
        continue;
      }
      counts[e.kind] = (counts[e.kind] ?? 0) + 1;
    }
    return counts.entries
        .map(
          (MapEntry<CalendarEventKind, int> e) =>
              '${e.value} ${e.key.label.toLowerCase()}',
        )
        .join(' · ');
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
