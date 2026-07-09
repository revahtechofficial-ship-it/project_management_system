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
                      label: Text(
                        _nepali ? 'बिदा थप्नुहोस्' : 'Add holiday',
                        softWrap: false,
                      ),
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
                    onJump: (int year, int month) =>
                        setState(() => _month = BsDate(year, month, 1)),
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
///
/// Hand-rolled rather than a [SegmentedButton]: that widget sizes every
/// segment to one shared intrinsic width, which it mismeasures on the web
/// when a Devanagari label falls back to a font that has not loaded yet —
/// so "English" wrapped mid-word.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.nepali, required this.onChanged});

  final bool nepali;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _LanguageChip(
            label: 'नेपाली',
            selected: nepali,
            onTap: () => onChanged(true),
          ),
          _LanguageChip(
            label: 'English',
            selected: !nepali,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Text(
            label,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
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
    required this.onJump,
  });

  final BsDate month;
  final List<DateTime> days;
  final DateTime selected;
  final bool nepali;
  final Map<String, List<CalendarEvent>> events;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;
  final void Function(int year, int month) onJump;

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
                Column(
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _BsYearPicker(
                          year: month.year,
                          nepali: nepali,
                          onChanged: (int year) => onJump(year, month.month),
                        ),
                        const SizedBox(width: 8),
                        _BsMonthPicker(
                          month: month.month,
                          nepali: nepali,
                          onChanged: (int m) => onJump(month.year, m),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: nepali ? 'अर्को महिना' : 'Next month',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  for (int col = 0; col < 7; col++)
                    Expanded(
                      // Matches the grid's crossAxisSpacing so the labels sit
                      // exactly over their columns.
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          children: <Widget>[
                            Text(
                              nepali
                                  ? kWeekdaysNeLong[col]
                                  : kWeekdaysEnLong[col],
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isWeekendColumn(col)
                                    ? scheme.error
                                    : scheme.onSurface,
                              ),
                            ),
                            Text(
                              nepali
                                  ? kWeekdaysEnLong[col]
                                  : kWeekdaysNeLong[col],
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                height: 1.4,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
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
                mainAxisExtent: 84,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
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

/// Jumps to any BS year within five years of today's.
class _BsYearPicker extends StatelessWidget {
  const _BsYearPicker({
    required this.year,
    required this.nepali,
    required this.onChanged,
  });

  final int year;
  final bool nepali;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final int current = bsToday().year;
    final List<int> years = <int>[
      for (int y = current - 5; y <= current + 5; y++) y,
    ];
    return DropdownButton<int>(
      value: years.contains(year) ? year : current,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(10),
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      items: <DropdownMenuItem<int>>[
        for (final int y in years)
          DropdownMenuItem<int>(
            value: y,
            child: Text(localDigits(y, nepali: nepali)),
          ),
      ],
      onChanged: (int? value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

/// Jumps to any month of the shown BS year.
class _BsMonthPicker extends StatelessWidget {
  const _BsMonthPicker({
    required this.month,
    required this.nepali,
    required this.onChanged,
  });

  final int month;
  final bool nepali;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value: month,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(10),
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      items: <DropdownMenuItem<int>>[
        for (int m = 1; m <= 12; m++)
          DropdownMenuItem<int>(
            value: m,
            child: Text(nepali ? kBsMonthsNe[m] : kBsMonthsEn[m]),
          ),
      ],
      onChanged: (int? value) {
        if (value != null) {
          onChanged(value);
        }
      },
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
    final bool isPublicHoliday = events.any(
      (CalendarEvent e) => e.isPublicHoliday,
    );
    final bool restDay = isWeekend(date) || isPublicHoliday;

    final Color foreground = isSelected
        ? scheme.onPrimary
        : restDay
        ? scheme.error
        : scheme.onSurface;

    // Holidays are named in the cell, so they need no dot of their own.
    final List<CalendarEventKind> kinds = <CalendarEventKind>[
      for (final CalendarEventKind kind in CalendarEventKind.values)
        if (kind != CalendarEventKind.holiday &&
            events.any((CalendarEvent e) => e.kind == kind))
          kind,
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
    final CalendarEvent? holiday = cellHoliday(events);

    final Widget cell = Material(
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
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 5),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final CalendarEventKind kind in kinds)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 2, top: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? scheme.onPrimary : kind.color,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    adLabel,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1,
                      color: isSelected
                          ? scheme.onPrimary.withValues(alpha: 0.85)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
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
              // A printed patro names its holidays. Everything else stays a
              // dot — a task title would never fit.
              SizedBox(
                height: 20,
                child: holiday == null
                    ? null
                    : Text(
                        holiday.name(nepali: nepali),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.5,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? scheme.onPrimary.withValues(alpha: 0.9)
                              : scheme.error,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (events.isEmpty) {
      return cell;
    }
    // A bare dot says nothing; hovering names everything on the day.
    return Tooltip(
      waitDuration: const Duration(milliseconds: 400),
      message: <String>[
        for (final CalendarEvent event in events) event.name(nepali: nepali),
      ].join('\n'),
      child: cell,
    );
  }
}

/// What the marks in the grid mean.
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
              // Holidays are named in red rather than dotted, so their swatch
              // shows the tint a holiday cell actually gets.
              if (kind == CalendarEventKind.holiday)
                Container(
                  width: 14,
                  height: 10,
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: scheme.error.withValues(alpha: 0.35),
                    ),
                  ),
                )
              else
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              nepali ? 'शनि/आइत' : 'Sat/Sun',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.error,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              nepali ? 'साप्ताहिक बिदा' : 'Weekend',
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

/// Upcoming and past events, one at a time — the two lists Hamro Patro shows
/// beside its grid.
class _UpcomingCard extends StatefulWidget {
  const _UpcomingCard({required this.nepali, required this.events});

  final bool nepali;
  final Map<String, List<CalendarEvent>> events;

  @override
  State<_UpcomingCard> createState() => _UpcomingCardState();
}

class _UpcomingCardState extends State<_UpcomingCard> {
  bool _past = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool nepali = widget.nepali;
    final List<CalendarEvent> shown = _past
        ? pastEvents(widget.events)
        : upcomingEvents(widget.events);

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
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(nepali ? 'आउँदा दिनहरू' : 'Upcoming'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(nepali ? 'बितेका' : 'Past'),
                ),
              ],
              selected: <bool>{_past},
              onSelectionChanged: (Set<bool> value) =>
                  setState(() => _past = value.first),
            ),
            const SizedBox(height: 14),
            if (shown.isEmpty)
              Text(
                _past
                    ? (nepali ? 'केही बितेको छैन।' : 'Nothing has passed.')
                    : (nepali ? 'केही आउँदैछैन।' : 'Nothing coming up.'),
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              for (final CalendarEvent event in shown)
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                // The date leads the line, as in a printed events list.
                if (showDate)
                  Text(
                    eventDateLine(event.date, nepali: nepali),
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  event.name(nepali: nepali),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.detail(nepali: nepali).isNotEmpty)
                  Text(
                    event.detail(nepali: nepali),
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
