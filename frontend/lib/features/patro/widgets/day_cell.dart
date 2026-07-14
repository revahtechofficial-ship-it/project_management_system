import 'package:flutter/material.dart';

import '../../../core/utils/nepali_calendar.dart';
import '../../../data/enums/calendar_event_kind.dart';
import '../providers/patro_providers.dart';
import 'day_popup.dart';

/// One day in the month grid.
///
/// Hovering it does one thing only — it lights the cell up, so you can see
/// where a click would land. The card is what a click is for. A card that came
/// up on hover would follow the pointer across a month the reader is only
/// trying to *read*, and reading a grid means crossing a great many days you
/// never meant to ask about.
class DayCell extends StatefulWidget {
  const DayCell({
    super.key,
    required this.date,
    required this.bsDay,
    required this.outside,
    required this.reserveNameLine,
    required this.nepali,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
    required this.onShowDetails,
    required this.onAddNote,
    required this.onSetReminder,
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

  /// The day card's quick actions.
  final VoidCallback onShowDetails;
  final VoidCallback onAddNote;
  final VoidCallback onSetReminder;

  @override
  State<DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<DayCell> {
  bool _hovered = false;

  /// Where the click landed, so the card can open under the hand rather than
  /// in the middle of the cell.
  Offset _clickedAt = Offset.zero;

  /// Selects the day — the grid highlight moves, the side panel fills — and
  /// raises the card at the cursor. Both, because a click on a day means both
  /// "this one" and "tell me about it".
  void _open() {
    widget.onTap();
    showDayPopup(
      context,
      at: _clickedAt,
      date: widget.date,
      nepali: widget.nepali,
      events: widget.events,
      onViewDetails: widget.onShowDetails,
      onAddNote: widget.onAddNote,
      onSetReminder: widget.onSetReminder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime date = widget.date;
    final bool outside = widget.outside;
    final bool nepali = widget.nepali;
    final bool isToday = widget.isToday;
    final bool isSelected = widget.isSelected;
    final List<CalendarEvent> events = widget.events;
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

    // Holidays are named in the cell and get a festival icon, so they need no
    // dot of their own; the dots are for the kinds that carry no other mark.
    final List<CalendarEventKind> kinds = <CalendarEventKind>[
      for (final CalendarEventKind kind in CalendarEventKind.values)
        if (kind != CalendarEventKind.holiday &&
            events.any((CalendarEvent e) => e.kind == kind))
          kind,
    ];

    // A day the reader has asked to be reminded about. Worth its own mark: a
    // dot says something is on, but a bell says the calendar will speak up.
    final bool hasReminder = events.any(
      (CalendarEvent e) => e.entry?.remindDays != null,
    );

    // The 1st of a Gregorian month carries its month name, so the AD calendar
    // stays readable as it drifts across the BS grid.
    final String adLabel = date.day == 1
        ? '${date.day} ${kAdMonthsShort[date.month]}'
        : '${date.day}';

    // Hovering does one thing and one thing only: it says which cell the click
    // would land on. It draws the outline the day already has, but firmly, so
    // the eye can run down a column without the calendar answering back.
    final Color border = isSelected
        ? Colors.transparent
        : _hovered
        ? scheme.primary.withValues(alpha: 0.7)
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
        onTapDown: (TapDownDetails d) => _clickedAt = d.globalPosition,
        onTap: _open,
        onHover: (bool hovering) => setState(() => _hovered = hovering),
        hoverColor: scheme.primary.withValues(alpha: 0.09),
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: border,
              width: (isToday || _hovered) && !isSelected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 5),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // A festival gets an icon rather than a dot — it is the one
                  // thing on the day a reader is scanning the month for.
                  if (holiday != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(
                        Icons.celebration,
                        size: 9,
                        color: isSelected
                            ? scheme.onPrimary
                            : scheme.error.withValues(alpha: dim),
                      ),
                    ),
                  if (hasReminder)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(
                        Icons.notifications_active,
                        size: 9,
                        color: isSelected
                            ? scheme.onPrimary
                            : scheme.tertiary.withValues(alpha: dim),
                      ),
                    ),
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
                    localDigits(widget.bsDay, nepali: nepali),
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
              if (widget.reserveNameLine)
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

    // Every day answers when clicked, not only the days that happen to carry an
    // event. The tithi, the sunrise and the moon are worth reading on an
    // ordinary Tuesday too, and a cell that answers only sometimes teaches the
    // reader to stop asking.
    return cell;
  }
}
