import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/feedback.dart';
import '../../core/utils/nepali_calendar.dart';
import '../../core/widgets/page_header.dart';
import '../../data/enums/calendar_event_kind.dart';
import '../../providers/auth_provider.dart';
import 'providers/patro_providers.dart';
import 'widgets/add_holiday_dialog.dart';

/// A dual Bikram Sambat + Gregorian calendar, in the spirit of Hamro Patro:
/// a BS month grid with the AD day in each cell, holidays, task due dates and
/// approved leave, all readable in Nepali or English.
class PatroPage extends ConsumerStatefulWidget {
  const PatroPage({super.key});

  @override
  ConsumerState<PatroPage> createState() => _PatroPageState();
}

class _PatroPageState extends ConsumerState<PatroPage> {
  bool _nepali = true;
  late BsDate _month = bsToday();
  late DateTime _selected = dateOnly(DateTime.now());

  void _shiftMonth(int delta) {
    setState(() => _month = addBsMonths(_month.year, _month.month, delta));
  }

  void _goToToday() {
    setState(() {
      _month = bsToday();
      _selected = dateOnly(DateTime.now());
    });
  }

  Future<void> _addHoliday() async {
    final bool? added = await showAddHolidayDialog(context, _selected);
    if ((added ?? false) && mounted) {
      context.showSuccess('Holiday added');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin =
        ref.watch(authControllerProvider).asData?.value.isAdmin ?? false;
    final Map<String, List<CalendarEvent>> events = ref.watch(
      calendarEventsProvider,
    );
    final List<DateTime> days = bsMonthDays(_month.year, _month.month);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          PageHeader(
            title: _nepali ? 'पात्रो' : 'Calendar',
            subtitle: _nepali
                ? 'नेपाली र अंग्रेजी पात्रो — बिदा, काम र छुट्टी सहित'
                : 'Bikram Sambat and Gregorian, with holidays, '
                      'due tasks and leave',
            actions: <Widget>[
              _LanguageToggle(
                nepali: _nepali,
                onChanged: (bool value) => setState(() => _nepali = value),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _goToToday,
                icon: const Icon(Icons.today_outlined, size: 18),
                label: Text(_nepali ? 'आज' : 'Today'),
              ),
              if (isAdmin) ...<Widget>[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addHoliday,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add holiday'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget grid = _MonthCard(
                month: _month,
                days: days,
                selected: _selected,
                nepali: _nepali,
                events: events,
                onPrevious: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
                onSelect: (DateTime day) => setState(() => _selected = day),
              );
              final Widget side = _SidePanel(
                selected: _selected,
                nepali: _nepali,
                events: events,
                isAdmin: isAdmin,
              );
              if (constraints.maxWidth < 900) {
                return Column(
                  children: <Widget>[grid, const SizedBox(height: 20), side],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 3, child: grid),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: side),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// नेपाली / English switch.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.nepali, required this.onChanged});

  final bool nepali;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(value: true, label: Text('नेपाली')),
        ButtonSegment<bool>(value: false, label: Text('English')),
      ],
      selected: <bool>{nepali},
      onSelectionChanged: (Set<bool> value) => onChanged(value.first),
    );
  }
}

/// The month header, weekday strip and day grid.
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.days,
    required this.selected,
    required this.nepali,
    required this.events,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final BsDate month;
  final List<DateTime> days;
  final DateTime selected;
  final bool nepali;
  final Map<String, List<CalendarEvent>> events;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime today = dateOnly(DateTime.now());
    final int leading = days.isEmpty ? 0 : sundayFirstIndex(days.first);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: nepali ? 'अघिल्लो महिना' : 'Previous month',
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        bsMonthLabel(month.year, month.month, nepali: nepali),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        adRangeLabel(days),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: nepali ? 'अर्को महिना' : 'Next month',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                for (int col = 0; col < 7; col++)
                  Expanded(
                    child: Text(
                      nepali ? kWeekdaysNe[col] : kWeekdaysEn[col],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: col == 6
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.92,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: <Widget>[
                for (int i = 0; i < leading; i++) const SizedBox.shrink(),
                for (int i = 0; i < days.length; i++)
                  _DayCell(
                    date: days[i],
                    bsDay: i + 1,
                    nepali: nepali,
                    isToday: isSameDay(days[i], today),
                    isSelected: isSameDay(days[i], selected),
                    events: events[dayKey(days[i])] ?? const <CalendarEvent>[],
                    onTap: () => onSelect(days[i]),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Legend(nepali: nepali),
          ],
        ),
      ),
    );
  }
}

/// One day: the BS day large, the AD day small, and a dot per event kind.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.bsDay,
    required this.nepali,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
  });

  final DateTime date;
  final int bsDay;
  final bool nepali;
  final bool isToday;
  final bool isSelected;
  final List<CalendarEvent> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isSaturday = sundayFirstIndex(date) == 6;
    final bool isPublicHoliday = events.any(
      (CalendarEvent e) => e.isPublicHoliday,
    );
    final bool restDay = isSaturday || isPublicHoliday;

    final Color foreground = isSelected
        ? scheme.onPrimary
        : restDay
        ? scheme.error
        : scheme.onSurface;

    final List<CalendarEventKind> kinds = <CalendarEventKind>[
      for (final CalendarEventKind kind in CalendarEventKind.values)
        if (events.any((CalendarEvent e) => e.kind == kind)) kind,
    ];

    return Material(
      color: isSelected
          ? scheme.primary
          : isPublicHoliday
          ? scheme.error.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isToday && !isSelected
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                localDigits(bsDay, nepali: nepali),
                style: TextStyle(
                  fontSize: 17,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  color: isSelected
                      ? scheme.onPrimary.withValues(alpha: 0.85)
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (final CalendarEventKind kind in kinds)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? scheme.onPrimary : kind.color,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the dots mean.
class _Legend extends StatelessWidget {
  const _Legend({required this.nepali});

  final bool nepali;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: <Widget>[
        for (final CalendarEventKind kind in CalendarEventKind.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kind.color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                nepali ? kind.labelNe : kind.label,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
      ],
    );
  }
}

/// The selected day's detail plus what is coming up.
class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.selected,
    required this.nepali,
    required this.events,
    required this.isAdmin,
  });

  final DateTime selected;
  final bool nepali;
  final Map<String, List<CalendarEvent>> events;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SelectedDayCard(
          selected: selected,
          nepali: nepali,
          events: events[dayKey(selected)] ?? const <CalendarEvent>[],
          isAdmin: isAdmin,
        ),
        const SizedBox(height: 16),
        _UpcomingCard(nepali: nepali, events: events),
      ],
    );
  }
}

class _SelectedDayCard extends ConsumerWidget {
  const _SelectedDayCard({
    required this.selected,
    required this.nepali,
    required this.events,
    required this.isAdmin,
  });

  final DateTime selected;
  final bool nepali;
  final List<CalendarEvent> events;
  final bool isAdmin;

  Future<void> _deleteHoliday(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    try {
      await ref.read(holidaysRepositoryProvider).delete(id);
      ref.invalidate(holidaysProvider);
      if (context.mounted) {
        context.showSuccess('Holiday removed');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not remove: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
            Text(
              fullDualDate(selected, nepali: nepali),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              fullDualDate(selected, nepali: !nepali),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const Divider(height: 24),
            if (events.isEmpty)
              Text(
                nepali ? 'यो दिन केही छैन।' : 'Nothing on this day.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              for (final CalendarEvent event in events)
                _EventTile(
                  event: event,
                  nepali: nepali,
                  onDelete: isAdmin && event.holidayId != null
                      ? () => _deleteHoliday(context, ref, event.holidayId!)
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.nepali, required this.events});

  final bool nepali;
  final Map<String, List<CalendarEvent>> events;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<CalendarEvent> upcoming = upcomingEvents(events);
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
            Text(
              nepali ? 'आगामी' : 'Upcoming',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (upcoming.isEmpty)
              Text(
                nepali ? 'केही आउँदैछैन।' : 'Nothing coming up.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              for (final CalendarEvent event in upcoming)
                _EventTile(event: event, nepali: nepali, showDate: true),
          ],
        ),
      ),
    );
  }
}

/// A single event line: coloured icon, title, and where it came from.
class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.nepali,
    this.showDate = false,
    this.onDelete,
  });

  final CalendarEvent event;
  final bool nepali;
  final bool showDate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BsDate bs = adToBs(event.date);
    final String dateLine = nepali
        ? '${kBsMonthsNe[bs.month]} ${toNepaliDigits(bs.day)} · '
              '${event.date.day} ${kAdMonthsShort[event.date.month]}'
        : '${kBsMonthsEn[bs.month]} ${bs.day} · '
              '${event.date.day} ${kAdMonthsShort[event.date.month]}';
    final String subtitle = showDate
        ? (event.subtitle.isEmpty ? dateLine : '$dateLine · ${event.subtitle}')
        : event.subtitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: event.kind.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(event.kind.icon, size: 16, color: event.kind.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  event.name(nepali: nepali),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Remove holiday',
            ),
        ],
      ),
    );
  }
}
