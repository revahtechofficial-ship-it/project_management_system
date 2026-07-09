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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: ListView(
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
                      children: <Widget>[
                        grid,
                        const SizedBox(height: 20),
                        side,
                      ],
                    );
                  }
                  // The panel is a fixed column, so the grid keeps a sane width
                  // instead of stretching its cells across the whole screen.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: grid),
                      const SizedBox(width: 20),
                      SizedBox(width: 340, child: side),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: nepali ? 'अघिल्लो महिना' : 'Previous month',
                ),
                SizedBox(
                  width: 200,
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
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                for (int col = 0; col < 7; col++)
                  Expanded(
                    // Matches the grid's crossAxisSpacing so the labels sit
                    // exactly over their columns.
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
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
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // A fixed cell height, not an aspect ratio: on a wide screen an
            // aspect ratio makes every cell as tall as the column is wide.
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: leading + days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 72,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (BuildContext context, int index) {
                if (index < leading) {
                  return const SizedBox.shrink();
                }
                final int i = index - leading;
                final DateTime date = days[i];
                return _DayCell(
                  date: date,
                  bsDay: i + 1,
                  nepali: nepali,
                  isToday: isSameDay(date, today),
                  isSelected: isSameDay(date, selected),
                  events: events[dayKey(date)] ?? const <CalendarEvent>[],
                  onTap: () => onSelect(date),
                );
              },
            ),
            const SizedBox(height: 16),
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

    // The 1st of a Gregorian month carries its month name, so the AD calendar
    // stays readable as it drifts across the BS grid.
    final String adLabel = date.day == 1
        ? '${date.day} ${kAdMonthsShort[date.month]}'
        : '${date.day}';

    final Color border = isSelected
        ? Colors.transparent
        : isToday
        ? scheme.primary
        : isPublicHoliday
        ? scheme.error.withValues(alpha: 0.35)
        : scheme.outlineVariant.withValues(alpha: 0.55);

    final BorderRadius radius = BorderRadius.circular(10);

    return Material(
      color: isSelected
          ? scheme.primary
          : isPublicHoliday
          ? scheme.error.withValues(alpha: 0.07)
          : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: border,
              width: isToday && !isSelected ? 1.5 : 1,
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 4,
                right: 6,
                child: Text(
                  adLabel,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    color: isSelected
                        ? scheme.onPrimary.withValues(alpha: 0.85)
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    localDigits(bsDay, nepali: nepali),
                    style: TextStyle(
                      fontSize: 19,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 7,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (final CalendarEventKind kind in kinds)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
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
      spacing: 16,
      runSpacing: 6,
      alignment: WrapAlignment.center,
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
