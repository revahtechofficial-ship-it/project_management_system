import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/nepali_calendar.dart';
import '../../core/widgets/page_header.dart';
import '../../data/enums/calendar_event_kind.dart';
import '../../data/models/calendar_entry.dart';
import '../../data/models/holiday.dart';
import '../../providers/auth_provider.dart';
import 'providers/patro_providers.dart';
import 'widgets/date_converter.dart';
import 'widgets/day_summary_card.dart';
import 'widgets/event_dialog.dart';
import 'widgets/festival_details.dart';
import 'widgets/holiday_dialog.dart';
import 'widgets/muhurta_card.dart';
import 'widgets/nepal_clock.dart';
import 'widgets/panchang_card.dart';
import 'widgets/pill_toggle.dart';
import 'widgets/rashifal_card.dart';

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
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The month [delta] away, or null when that would leave the range the year
  /// picker offers (and, further out, the range the conversion table covers).
  BsDate? _monthAway(int delta) {
    final BsDate next = addBsMonths(_month.year, _month.month, delta);
    if (next.year < kBsPickerMinYear || next.year > kBsPickerMaxYear) {
      return null;
    }
    return next;
  }

  void _shiftMonth(int delta) {
    final BsDate? next = _monthAway(delta);
    if (next != null) {
      setState(() => _month = next);
    }
  }

  /// Selects [day] and brings its BS month into view. Used by the grid, by the
  /// greyed days of the neighbouring months, and by the event lists.
  void _openDate(DateTime day) {
    final BsDate bs = adToBs(day);
    setState(() {
      _selected = dateOnly(day);
      _month = BsDate(bs.year, bs.month, 1);
    });
  }

  Future<void> _addEvent() async {
    final bool? added = await showEventDialog(context, initialDate: _selected);
    if ((added ?? false) && mounted) {
      context.showSuccess('Event added');
    }
  }

  Future<void> _addHoliday() async {
    final bool? added = await showHolidayDialog(
      context,
      initialDate: _selected,
    );
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
    final bool holidaysFailed = ref.watch(holidaysProvider).hasError;
    final DateTime today = dateOnly(DateTime.now());
    final BsDate bsNow = bsToday();
    final bool alreadyOnToday =
        isSameDay(_selected, today) &&
        _month.year == bsNow.year &&
        _month.month == bsNow.month;

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
                  PillToggle(
                    labels: const <String>['नेपाली', 'English'],
                    selected: _nepali ? 0 : 1,
                    onChanged: (int i) => setState(() => _nepali = i == 0),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: alreadyOnToday ? null : () => _openDate(today),
                    icon: const Icon(Icons.today_outlined, size: 18),
                    label: Text(_nepali ? 'आज' : 'Today', softWrap: false),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _addEvent,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      _nepali ? 'कार्यक्रम थप्नुहोस्' : 'Add event',
                      softWrap: false,
                    ),
                  ),
                  if (isAdmin) ...<Widget>[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _addHoliday,
                      icon: const Icon(Icons.celebration_outlined, size: 18),
                      label: Text(
                        _nepali ? 'बिदा' : 'Add holiday',
                        softWrap: false,
                      ),
                    ),
                  ],
                ],
              ),
              // Holidays are the point of this page, so a silent empty grid
              // would be worse than saying the fetch failed.
              if (holidaysFailed) ...<Widget>[
                const SizedBox(height: 16),
                _HolidaysUnavailable(
                  nepali: _nepali,
                  onRetry: () => ref.invalidate(holidaysProvider),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (String v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: _nepali
                      ? 'पर्व खोज्नुहोस् — दशैं, तिहार, होली…'
                      : 'Search festivals — Dashain, Tihar, Holi…',
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_query.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _SearchResults(
                  query: _query,
                  nepali: _nepali,
                  onOpenDate: (DateTime day) {
                    _search.clear();
                    setState(() => _query = '');
                    _openDate(day);
                  },
                ),
              ],
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget grid = _MonthCard(
                    month: _month,
                    selected: _selected,
                    nepali: _nepali,
                    events: events,
                    onPrevious: _monthAway(-1) == null
                        ? null
                        : () => _shiftMonth(-1),
                    onNext: _monthAway(1) == null ? null : () => _shiftMonth(1),
                    onOpenDate: _openDate,
                    onJump: (int year, int month) =>
                        setState(() => _month = BsDate(year, month, 1)),
                  );
                  final Widget side = _SidePanel(
                    selected: _selected,
                    nepali: _nepali,
                    events: events,
                    isAdmin: isAdmin,
                    onOpenDate: _openDate,
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

/// Festivals matching the search box, by name or by any of their other names.
class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.nepali,
    required this.onOpenDate,
  });

  final String query;
  final bool nepali;
  final ValueChanged<DateTime> onOpenDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Holiday> all =
        ref.watch(holidaysProvider).asData?.value ?? const <Holiday>[];
    final List<Holiday> hits = searchHolidays(all, query);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: hits.isEmpty
            ? Text(
                nepali
                    ? '"$query" सँग मिल्ने पर्व भेटिएन।'
                    : 'No festival matches "$query".',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final Holiday holiday in hits)
                    _SearchHit(
                      holiday: holiday,
                      nepali: nepali,
                      onTap: () => onOpenDate(holiday.date),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SearchHit extends StatelessWidget {
  const _SearchHit({
    required this.holiday,
    required this.nepali,
    required this.onTap,
  });

  final Holiday holiday;
  final bool nepali;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              holiday.category.icon,
              size: 16,
              color: holiday.category.color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                holiday.name(nepali: nepali),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              eventDateLine(holiday.date, nepali: nepali),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when `/api/v1/holidays` cannot be reached — otherwise the grid just
/// looks like a year with no festivals in it.
class _HolidaysUnavailable extends StatelessWidget {
  const _HolidaysUnavailable({required this.nepali, required this.onRetry});

  final bool nepali;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off_outlined, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nepali
                  ? 'बिदाहरू लोड गर्न सकिएन। पात्रो बाँकी सबै देखाउँदैछ।'
                  : 'Holidays could not be loaded. The rest of the calendar '
                        'still works.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(nepali ? 'फेरि प्रयास' : 'Retry'),
          ),
        ],
      ),
    );
  }
}

/// One square of the grid: a date, its BS day, and whether it belongs to the
/// month on screen or to a neighbour.
class _GridDay {
  const _GridDay(this.date, this.bsDay, {required this.outside});

  /// Places [date] against the month on screen, greying it when it belongs to
  /// a neighbouring BS month.
  factory _GridDay.of(DateTime date, BsDate month) {
    final BsDate bs = adToBs(date);
    return _GridDay(
      date,
      bs.day,
      outside: bs.month != month.month || bs.year != month.year,
    );
  }

  final DateTime date;
  final int bsDay;
  final bool outside;
}

/// The month header, weekday strip and day grid.
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.selected,
    required this.nepali,
    required this.events,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenDate,
    required this.onJump,
  });

  final BsDate month;
  final DateTime selected;
  final bool nepali;
  final Map<String, List<CalendarEvent>> events;

  /// Null at the ends of the supported year range, which disables the chevron
  /// and the swipe in that direction.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<DateTime> onOpenDate;
  final void Function(int year, int month) onJump;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime today = dateOnly(DateTime.now());
    final List<DateTime> days = bsMonthDays(month.year, month.month);
    final List<_GridDay> cells = <_GridDay>[
      for (final DateTime date in bsMonthGrid(month.year, month.month))
        _GridDay.of(date, month),
    ];

    // Reserve the name line for every cell or for none, so the BS numerals
    // stay on one baseline across a row. Most months have no holiday at all,
    // and reserving the line there would just leave dead space.
    final bool reserveNameLine = cells.any(
      (_GridDay c) =>
          cellHoliday(events[dayKey(c.date)] ?? const <CalendarEvent>[]) !=
          null,
    );

    return GestureDetector(
      // Swipe the month across, as on a phone. A flick left goes forward;
      // the velocity gate keeps a slow drag over a day cell from paging.
      onHorizontalDragEnd: (DragEndDetails details) {
        final double velocity = details.primaryVelocity ?? 0;
        if (velocity > 250) {
          onPrevious?.call();
        } else if (velocity < -250) {
          onNext?.call();
        }
      },
      child: Card(
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
                                  fontSize: 10,
                                  height: 1.3,
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
                itemCount: cells.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: reserveNameLine ? 84 : 66,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final _GridDay cell = cells[index];
                  return _DayCell(
                    date: cell.date,
                    bsDay: cell.bsDay,
                    outside: cell.outside,
                    reserveNameLine: reserveNameLine,
                    nepali: nepali,
                    isToday: isSameDay(cell.date, today),
                    isSelected: isSameDay(cell.date, selected),
                    events:
                        events[dayKey(cell.date)] ?? const <CalendarEvent>[],
                    onTap: () => onOpenDate(cell.date),
                  );
                },
              ),
              const SizedBox(height: 16),
              _Legend(nepali: nepali),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jumps to any BS year the conversion table covers.
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
    return DropdownButton<int>(
      value: year >= kBsPickerMinYear && year <= kBsPickerMaxYear
          ? year
          : current,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(10),
      menuMaxHeight: 320,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      items: <DropdownMenuItem<int>>[
        for (int y = kBsPickerMinYear; y <= kBsPickerMaxYear; y++)
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

/// One day: the BS day large, the AD day small, holidays named, everything
/// else dotted.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.bsDay,
    required this.outside,
    required this.reserveNameLine,
    required this.nepali,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
  });

  final DateTime date;
  final int bsDay;

  /// True for the neighbouring months' days that pad the rectangle out.
  final bool outside;
  final bool reserveNameLine;
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
        : outside
        ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
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
        : outside
        ? scheme.outlineVariant.withValues(alpha: 0.25)
        : isPublicHoliday
        ? scheme.error.withValues(alpha: 0.35)
        : scheme.outlineVariant.withValues(alpha: 0.55);

    final BorderRadius radius = BorderRadius.circular(10);
    final CalendarEvent? holiday = cellHoliday(events);
    final double dim = outside ? 0.45 : 1;

    final Widget cell = Material(
      color: isSelected
          ? scheme.primary
          : isPublicHoliday && !outside
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
                        color: isSelected
                            ? scheme.onPrimary
                            : kind.color.withValues(alpha: dim),
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
                          : scheme.onSurfaceVariant.withValues(alpha: dim),
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
              if (reserveNameLine)
                SizedBox(
                  height: 22,
                  child: holiday == null
                      ? null
                      : Text(
                          holiday.name(nepali: nepali),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.5,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? scheme.onPrimary.withValues(alpha: 0.9)
                                : scheme.error.withValues(alpha: dim),
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
    required this.onOpenDate,
  });

  final DateTime selected;
  final bool nepali;
  final Map<String, List<CalendarEvent>> events;
  final bool isAdmin;
  final ValueChanged<DateTime> onOpenDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        NepalClock(nepali: nepali),
        const SizedBox(height: 16),
        _SelectedDayCard(
          selected: selected,
          nepali: nepali,
          events: events[dayKey(selected)] ?? const <CalendarEvent>[],
          isAdmin: isAdmin,
        ),
        const SizedBox(height: 16),
        DaySummaryCard(date: selected, nepali: nepali),
        const SizedBox(height: 16),
        PanchangCard(date: selected, nepali: nepali),
        const SizedBox(height: 16),
        MuhurtaCard(date: selected, nepali: nepali),
        const SizedBox(height: 16),
        RashifalCard(date: selected, nepali: nepali),
        const SizedBox(height: 16),
        _UpcomingCard(nepali: nepali, events: events, onOpenDate: onOpenDate),
        const SizedBox(height: 16),
        DateConverter(nepali: nepali, onOpenDate: onOpenDate),
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

  /// Removes one of the caller's own entries. No confirmation: it is theirs,
  /// it is one row, and the snackbar says what happened.
  Future<void> _deleteEntry(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(calendarEntriesRepositoryProvider).delete(id);
      ref.invalidate(calendarEntriesProvider);
      if (context.mounted) {
        context.showSuccess('Event removed');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Could not remove: $e');
      }
    }
  }

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
    final BsDate bs = adToBs(selected);
    final int col = sundayFirstIndex(selected);

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
            if (isWeekend(selected)) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  nepali ? 'साप्ताहिक बिदा' : 'Weekend',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.error,
                  ),
                ),
              ),
            ],
            const Divider(height: 20),
            _DetailRow(
              label: nepali ? 'नेपाली मिति' : 'Nepali date',
              value: bsDateText(bs, nepali: nepali),
            ),
            _DetailRow(
              label: nepali ? 'अंग्रेजी मिति' : 'English date',
              value: formatLongDate(selected),
            ),
            _DetailRow(
              label: nepali ? 'वार' : 'Day of week',
              value: '${kWeekdaysNeLong[col]} · ${kWeekdaysEnLong[col]}',
            ),
            _DetailRow(
              label: nepali ? 'नेपाली महिना' : 'Nepali month',
              value:
                  '${nepali ? kBsMonthsNe[bs.month] : kBsMonthsEn[bs.month]} '
                  '(${localDigits(bs.month, nepali: nepali)}/'
                  '${localDigits(12, nepali: nepali)})',
            ),
            _DetailRow(
              label: nepali ? 'अंग्रेजी महिना' : 'English month',
              value: '${monthLong(selected.month)} (${selected.month}/12)',
            ),
            _DetailRow(
              label: nepali ? 'विक्रम संवत्' : 'BS year',
              value: localDigits(bs.year, nepali: nepali),
            ),
            _DetailRow(
              label: nepali ? 'ईस्वी संवत्' : 'AD year',
              value: '${selected.year}',
            ),
            _DetailRow(
              label: nepali ? 'गते' : 'Day number',
              value:
                  'BS ${localDigits(bs.day, nepali: nepali)} · '
                  'AD ${selected.day}',
            ),
            _DetailRow(
              label: nepali ? 'हप्ता' : 'Week number',
              value:
                  '${nepali ? 'वि.सं.' : 'BS'} '
                  '${localDigits(bsWeekOfYear(selected), nepali: nepali)} · '
                  'ISO ${localDigits(isoWeekNumber(selected), nepali: nepali)}',
            ),
            const Divider(height: 20),
            if (events.isEmpty)
              Text(
                nepali ? 'यो दिन केही छैन।' : 'Nothing on this day.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              for (final CalendarEvent event in events) ...<Widget>[
                _EventTile(
                  event: event,
                  nepali: nepali,
                  // A holiday is the country's, so only an admin may touch it.
                  // A personal entry is the caller's own, always.
                  onEdit: switch (event) {
                    CalendarEvent(entry: final CalendarEntry e?) =>
                      () => showEventDialog(context, existing: e),
                    CalendarEvent(holiday: final Holiday h?) when isAdmin =>
                      () => showHolidayDialog(context, existing: h),
                    _ => null,
                  },
                  onDelete: switch (event) {
                    CalendarEvent(entry: final CalendarEntry e?) =>
                      () => _deleteEntry(context, ref, e.id),
                    CalendarEvent(holiday: final Holiday h?) when isAdmin =>
                      () => _deleteHoliday(context, ref, h.id),
                    _ => null,
                  },
                ),
                if (event.holiday != null)
                  FestivalDetails(holiday: event.holiday!, nepali: nepali),
              ],
          ],
        ),
      ),
    );
  }
}

/// One labelled fact about the selected day.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Upcoming and past events, one at a time — the two lists Hamro Patro shows
/// beside its grid.
class _UpcomingCard extends StatefulWidget {
  const _UpcomingCard({
    required this.nepali,
    required this.events,
    required this.onOpenDate,
  });

  final bool nepali;
  final Map<String, List<CalendarEvent>> events;
  final ValueChanged<DateTime> onOpenDate;

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
            Align(
              alignment: Alignment.centerLeft,
              child: PillToggle(
                labels: <String>[
                  nepali ? 'आउँदा' : 'Upcoming',
                  nepali ? 'बितेका' : 'Past',
                ],
                selected: _past ? 1 : 0,
                onChanged: (int i) => setState(() => _past = i == 1),
              ),
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
                _EventTile(
                  event: event,
                  nepali: nepali,
                  showDate: true,
                  onTap: () => widget.onOpenDate(event.date),
                ),
          ],
        ),
      ),
    );
  }
}

/// A single event line: coloured icon, the date, the name, and its detail.
class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.nepali,
    this.showDate = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final CalendarEvent event;
  final bool nepali;
  final bool showDate;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String detail = event.detail(nepali: nepali);

    // A festival wears its category — a temple for religious, a flag for
    // national — rather than the same confetti icon as every other holiday.
    final Holiday? holiday = event.holiday;
    final IconData icon = holiday != null
        ? holiday.category.icon
        : event.kind.icon;
    final Color tint = holiday != null
        ? holiday.category.color
        : event.kind.color;

    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: tint),
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
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 17),
              tooltip: 'Edit holiday',
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

    if (onTap == null) {
      return row;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: row,
    );
  }
}
