import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/date_search.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/nepali_calendar.dart';
import '../../core/widgets/page_header.dart';
import '../../data/enums/calendar_event_kind.dart';
import '../../data/models/calendar_entry.dart';
import '../../data/models/holiday.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import 'providers/patro_providers.dart';
import 'widgets/date_converter.dart';
import 'widgets/day_cell.dart';
import 'widgets/day_summary_card.dart';
import 'widgets/event_dialog.dart';
import 'widgets/festival_details.dart';
import 'widgets/holiday_dialog.dart';
import 'widgets/holiday_reminder_card.dart';
import 'widgets/muhurta_card.dart';
import 'widgets/nepal_clock.dart';
import 'widgets/panchang_card.dart';
import 'widgets/pill_toggle.dart';
import 'widgets/rashifal_card.dart';
import 'widgets/share_dialog.dart';

/// A dual Bikram Sambat + Gregorian calendar, in the spirit of Hamro Patro:
/// a BS month grid with the AD day in each cell, holidays, task due dates and
/// approved leave, all readable in Nepali or English.
class PatroPage extends ConsumerStatefulWidget {
  const PatroPage({super.key});

  @override
  ConsumerState<PatroPage> createState() => _PatroPageState();
}

class _PatroPageState extends ConsumerState<PatroPage> {
  late BsDate _month = bsToday();
  late DateTime _selected = dateOnly(DateTime.now());
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// Marks the side panel, so the popup's "Details" button can scroll to it.
  final GlobalKey _panelKey = GlobalKey();

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

  /// A year is twelve months, so year navigation is month navigation — which
  /// means it inherits the same bounds check and cannot walk off the table.
  BsDate? _yearAway(int delta) => _monthAway(delta * 12);

  void _shiftYear(int delta) => _shiftMonth(delta * 12);

  /// Selects [day] and brings its BS month into view. Used by the grid, by the
  /// greyed days of the neighbouring months, and by the event lists.
  void _openDate(DateTime day) {
    final BsDate bs = adToBs(day);
    setState(() {
      _selected = dateOnly(day);
      _month = BsDate(bs.year, bs.month, 1);
    });
  }

  /// Selects [day] and brings the side panel — the long form of everything the
  /// popup summarised — into view. On a wide screen the panel is already
  /// beside the grid and nothing scrolls; on a narrow one it sits below the
  /// month, which is exactly where "view details" ought to take you.
  void _showDetails(DateTime day) {
    _openDate(day);
    final BuildContext? panel = _panelKey.currentContext;
    if (panel == null) {
      return;
    }
    Scrollable.ensureVisible(
      panel,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  Future<void> _addEvent() async {
    final bool? added = await showEventDialog(context, initialDate: _selected);
    if ((added ?? false) && mounted) {
      context.showSuccess('Event added');
    }
  }

  /// From the hover card: open the editor already pointed at the day under the
  /// cursor, so "Note" on the 25th does not open a form for today.
  Future<void> _addNoteOn(DateTime day) async {
    _openDate(day);
    final bool? added = await showEventDialog(context, initialDate: day);
    if ((added ?? false) && mounted) {
      context.showSuccess('Note added');
    }
  }

  /// The same editor, but with a reminder already asked for — which is the only
  /// difference between a note and a reminder here.
  Future<void> _addReminderOn(DateTime day) async {
    _openDate(day);
    final bool? added = await showEventDialog(
      context,
      initialDate: day,
      remindByDefault: true,
    );
    if ((added ?? false) && mounted) {
      context.showSuccess('Reminder set');
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
    // Global and persisted, so the choice survives a refresh.
    final bool nepali = ref.watch(nepaliProvider);
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
                title: nepali ? 'पात्रो' : 'Calendar',
                subtitle: nepali
                    ? 'नेपाली र अंग्रेजी पात्रो — बिदा, काम र छुट्टी सहित'
                    : 'Bikram Sambat and Gregorian, with holidays, '
                          'due tasks and leave',
                actions: <Widget>[
                  PillToggle(
                    labels: const <String>['नेपाली', 'English'],
                    selected: nepali ? 0 : 1,
                    onChanged: (int i) =>
                        ref.read(nepaliProvider.notifier).setNepali(i == 0),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: alreadyOnToday ? null : () => _openDate(today),
                    icon: const Icon(Icons.today_outlined, size: 18),
                    label: Text(nepali ? 'आज' : 'Today', softWrap: false),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => showShareDialog(
                      context,
                      date: _selected,
                      nepali: nepali,
                      events:
                          events[dayKey(_selected)] ?? const <CalendarEvent>[],
                    ),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(nepali ? 'साझा' : 'Share', softWrap: false),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _addEvent,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      nepali ? 'कार्यक्रम थप्नुहोस्' : 'Add event',
                      softWrap: false,
                    ),
                  ),
                  if (isAdmin) ...<Widget>[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _addHoliday,
                      icon: const Icon(Icons.celebration_outlined, size: 18),
                      label: Text(
                        nepali ? 'बिदा' : 'Add holiday',
                        softWrap: false,
                      ),
                    ),
                  ],
                ],
              ),
              // The live Nepal time runs across the top as a slim bar, the
              // first thing under the title — not buried among the day's cards.
              const SizedBox(height: 16),
              NepalClock(nepali: nepali),
              // Holidays are the point of this page, so a silent empty grid
              // would be worse than saying the fetch failed.
              if (holidaysFailed) ...<Widget>[
                const SizedBox(height: 16),
                _HolidaysUnavailable(
                  nepali: nepali,
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
                  hintText: nepali
                      ? 'खोज्नुहोस् — दशैं, होली, २०८३-०३-२५, असार २५'
                      : 'Search — Dashain, Holi, 2083-03-25, 9 July 2026',
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
                  nepali: nepali,
                  onOpenDate: (DateTime day) {
                    _search.clear();
                    setState(() => _query = '');
                    _openDate(day);
                  },
                ),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget grid = _MonthCard(
                    month: _month,
                    selected: _selected,
                    nepali: nepali,
                    events: events,
                    onPrevious: _monthAway(-1) == null
                        ? null
                        : () => _shiftMonth(-1),
                    onNext: _monthAway(1) == null ? null : () => _shiftMonth(1),
                    onPreviousYear: _yearAway(-1) == null
                        ? null
                        : () => _shiftYear(-1),
                    onNextYear: _yearAway(1) == null
                        ? null
                        : () => _shiftYear(1),
                    onOpenDate: _openDate,
                    onJump: (int year, int month) =>
                        setState(() => _month = BsDate(year, month, 1)),
                    onShowDetails: _showDetails,
                    onAddNote: _addNoteOn,
                    onSetReminder: _addReminderOn,
                  );
                  return _PatroBento(
                    panelKey: _panelKey,
                    grid: grid,
                    selected: _selected,
                    nepali: nepali,
                    events: events,
                    isAdmin: isAdmin,
                    stacked: constraints.maxWidth < 900,
                    onOpenDate: _openDate,
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

    // The same box takes a date as well as a festival name. A year that both
    // calendars could claim comes back twice, labelled, rather than guessed at.
    final List<DateMatch> dates = searchDates(query);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: hits.isEmpty && dates.isEmpty
            ? Text(
                nepali
                    ? '"$query" सँग मिल्ने पर्व वा मिति भेटिएन।'
                    : 'No festival or date matches "$query".',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final DateMatch m in dates)
                    _DateHit(
                      match: m,
                      nepali: nepali,
                      onTap: () => onOpenDate(m.date),
                    ),
                  if (dates.isNotEmpty && hits.isNotEmpty)
                    const Divider(height: 14),
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

/// A date the query could have meant, and which calendar it was read in.
class _DateHit extends StatelessWidget {
  const _DateHit({
    required this.match,
    required this.nepali,
    required this.onTap,
  });

  final DateMatch match;
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
            Icon(Icons.event_outlined, size: 16, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fullDualDate(match.date, nepali: nepali),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Which calendar this reading came from. Without it, two results
            // for one query would look like a bug.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                nepali ? match.readAs.labelNe : match.readAs.short,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
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
    required this.onPreviousYear,
    required this.onNextYear,
    required this.onOpenDate,
    required this.onJump,
    required this.onShowDetails,
    required this.onAddNote,
    required this.onSetReminder,
  });

  final BsDate month;
  final DateTime selected;
  final bool nepali;
  final Map<String, List<CalendarEvent>> events;

  /// Null at the ends of the supported year range, which disables the chevron
  /// and the swipe in that direction.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// A whole year at a step, for the reader who is looking for last Dashain.
  final VoidCallback? onPreviousYear;
  final VoidCallback? onNextYear;

  final ValueChanged<DateTime> onOpenDate;
  final void Function(int year, int month) onJump;

  /// The day card's quick actions, for the day that was clicked.
  final ValueChanged<DateTime> onShowDetails;
  final ValueChanged<DateTime> onAddNote;
  final ValueChanged<DateTime> onSetReminder;

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
                  return DayCell(
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
                    onShowDetails: () => onShowDetails(cell.date),
                    onAddNote: () => onAddNote(cell.date),
                    onSetReminder: () => onSetReminder(cell.date),
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
                Icon(Icons.celebration, size: 11, color: scheme.error)
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
            Icon(Icons.notifications_active, size: 11, color: scheme.tertiary),
            const SizedBox(width: 6),
            Text(
              nepali ? 'सम्झना' : 'Reminder set',
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

/// The whole almanac laid out as a bento grid, so the width does the work and
/// the page barely scrolls — instead of a narrow 340px column stacking nine
/// cards into a tall ribbon nobody reaches the bottom of.
///
/// The arrangement follows the owner's sketch: the clock and the converter
/// share the top; the month sits large beside the selected day's detail and
/// its story; the panchang and the muhurtas face the rashifal; the events run
/// full width along the foot. On a narrow screen it all falls into one column,
/// the month first.
class _PatroBento extends StatelessWidget {
  const _PatroBento({
    required this.panelKey,
    required this.grid,
    required this.selected,
    required this.nepali,
    required this.events,
    required this.isAdmin,
    required this.stacked,
    required this.onOpenDate,
  });

  /// Marks the selected-day card, so the popup's "Details" button can scroll
  /// straight to it wherever the layout has put it.
  final Key panelKey;
  final Widget grid;
  final DateTime selected;
  final bool nepali;
  final Map<String, List<CalendarEvent>> events;
  final bool isAdmin;
  final bool stacked;
  final ValueChanged<DateTime> onOpenDate;

  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    // The clock is not here — it runs as a bar across the top of the page,
    // above this grid entirely.
    final Widget converter = DateConverter(
      nepali: nepali,
      onOpenDate: onOpenDate,
    );
    final Widget dateInfo = KeyedSubtree(
      key: panelKey,
      child: _SelectedDayCard(
        selected: selected,
        nepali: nepali,
        events: events[dayKey(selected)] ?? const <CalendarEvent>[],
        isAdmin: isAdmin,
      ),
    );
    final Widget aboutDay = DaySummaryCard(date: selected, nepali: nepali);
    final Widget panchang = PanchangCard(date: selected, nepali: nepali);
    final Widget muhurta = MuhurtaCard(date: selected, nepali: nepali);
    final Widget rashifal = RashifalCard(date: selected, nepali: nepali);
    final Widget reminder = HolidayReminderCard(nepali: nepali);
    final Widget upcoming = _UpcomingCard(
      nepali: nepali,
      events: events,
      onOpenDate: onOpenDate,
    );

    if (stacked) {
      // One column, the calendar first, everything else beneath it in reading
      // order. Still shorter than before, because there is no duplicate side
      // rail — the same cards, once each.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final Widget card in <Widget>[
            converter,
            grid,
            dateInfo,
            aboutDay,
            panchang,
            muhurta,
            rashifal,
            reminder,
            upcoming,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: _gap),
              child: card,
            ),
        ],
      );
    }

    // A true masonry over every card, events included: each drops into
    // whichever column is *currently* shortest, so the two finish within one
    // small card of each other whatever the day's content happens to weigh. The
    // hand-placed columns before this could not — the imbalance was always
    // smaller than any single card left to move, so moving one only flipped the
    // gap to the other side.
    //
    // Two rules keep it both balanced and legible. The biggest cards go early,
    // so they split across the two columns rather than piling on one; the two
    // smallest go last, so they settle into whichever column is short and level
    // the pair off. And the events — the tallest thing here — are *not* held
    // out in a full-width band beneath, because any band sits below the taller
    // column and reopens the very gap this is meant to close. In the masonry
    // they simply take a column, and the only unevenness left is a few pixels
    // at the foot of the page, where nothing draws the eye to it.
    //
    // The month still leads (top-left) and the day's detail follows (top-right).
    final List<Widget> cards = <Widget>[
      grid,
      upcoming,
      dateInfo,
      panchang,
      rashifal,
      muhurta,
      converter,
      reminder,
      aboutDay,
    ];
    return MasonryGridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: _gap,
      crossAxisSpacing: _gap,
      itemCount: cards.length,
      itemBuilder: (BuildContext context, int index) => cards[index],
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
        context.showError(e);
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
        context.showError(e);
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
            // A titled header with the toggle to its right, like the other
            // cards, so the events band reads as a section rather than a loose
            // list under a switch.
            Row(
              children: <Widget>[
                Icon(
                  Icons.event_note_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  nepali ? 'कार्यक्रमहरू' : 'Events',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                PillToggle(
                  labels: <String>[
                    nepali ? 'आउँदा' : 'Upcoming',
                    nepali ? 'बितेका' : 'Past',
                  ],
                  selected: _past ? 1 : 0,
                  onChanged: (int i) => setState(() => _past = i == 1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _past
                      ? (nepali ? 'केही बितेको छैन।' : 'Nothing has passed.')
                      : (nepali ? 'केही आउँदैछैन।' : 'Nothing coming up.'),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              // Tiled across the width — two or three columns as it fits — so a
              // full-width band is full, not a narrow list with an empty half
              // beside it. Round-robin, so reading left to right stays in date
              // order.
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final int cols = c.maxWidth >= 980
                      ? 3
                      : c.maxWidth >= 460
                      ? 2
                      : 1;
                  final List<List<Widget>> columns = <List<Widget>>[
                    for (int k = 0; k < cols; k++) <Widget>[],
                  ];
                  for (int i = 0; i < shown.length; i++) {
                    final CalendarEvent event = shown[i];
                    columns[i % cols].add(
                      _EventTile(
                        event: event,
                        nepali: nepali,
                        showDate: true,
                        onTap: () => widget.onOpenDate(event.date),
                      ),
                    );
                  }
                  if (cols == 1) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: columns.first,
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (int k = 0; k < cols; k++) ...<Widget>[
                        if (k > 0) const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: columns[k],
                          ),
                        ),
                      ],
                    ],
                  );
                },
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
