import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/nepali_calendar.dart';
import '../../../data/enums/calendar_event_kind.dart';
import '../../../data/enums/festival_category.dart';
import '../../../data/models/holiday.dart';
import '../../../data/models/leave_request.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/holidays_repository.dart';
import '../../../providers/dio_provider.dart';
import '../../leave/providers/leave_providers.dart';
import '../../tasks/providers/tasks_providers.dart';

/// The holidays repository, from the shared Dio client (AGENTS.md §1).
final Provider<HolidaysRepository> holidaysRepositoryProvider =
    Provider<HolidaysRepository>((ref) {
      return HolidaysRepository(ref.watch(dioProvider));
    });

/// Holidays across the server's default window (about a year back and two
/// forward). Invalidate after adding or removing one.
final FutureProvider<List<Holiday>> holidaysProvider =
    FutureProvider<List<Holiday>>((ref) {
      return ref.watch(holidaysRepositoryProvider).list();
    });

/// One entry on the calendar, whatever its origin.
class CalendarEvent {
  const CalendarEvent({
    required this.date,
    required this.kind,
    required this.title,
    this.titleNe = '',
    this.subtitle = '',
    this.subtitleNe = '',
    this.holiday,
    this.isPublicHoliday = false,
  });

  /// The Gregorian day the event falls on.
  final DateTime date;
  final CalendarEventKind kind;
  final String title;
  final String titleNe;
  final String subtitle;
  final String subtitleNe;

  /// Set only for holidays: the festival behind this event, so the day panel
  /// can show its detail and an admin can edit or delete it.
  final Holiday? holiday;

  /// A public holiday tints its whole day cell red; a non-public one only
  /// shows its name.
  final bool isPublicHoliday;

  /// The title in the requested language, falling back to the other.
  String name({required bool nepali}) {
    if (nepali && titleNe.isNotEmpty) {
      return titleNe;
    }
    return title.isNotEmpty ? title : titleNe;
  }

  /// The supporting line in the requested language, falling back to the other.
  String detail({required bool nepali}) {
    if (nepali && subtitleNe.isNotEmpty) {
      return subtitleNe;
    }
    return subtitle.isNotEmpty ? subtitle : subtitleNe;
  }

  @override
  String toString() => 'CalendarEvent(${dayKey(date)}, ${kind.name}, $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEvent &&
          other.date == date &&
          other.kind == kind &&
          other.title == title &&
          other.titleNe == titleNe &&
          other.subtitle == subtitle &&
          other.subtitleNe == subtitleNe &&
          other.holiday == holiday &&
          other.isPublicHoliday == isPublicHoliday;

  @override
  int get hashCode => Object.hash(
    date,
    kind,
    title,
    titleNe,
    subtitle,
    subtitleNe,
    holiday,
    isPublicHoliday,
  );
}

/// Every calendar event, grouped by `yyyy-mm-dd`.
///
/// Merges three sources — holidays, task due dates, and approved leave — so
/// the grid and the upcoming list read from one place. Sources that are still
/// loading (or that failed) simply contribute nothing, which keeps the
/// calendar usable while the slower ones arrive.
final Provider<Map<String, List<CalendarEvent>>>
calendarEventsProvider = Provider<Map<String, List<CalendarEvent>>>((ref) {
  final List<Holiday> holidays =
      ref.watch(holidaysProvider).asData?.value ?? const <Holiday>[];
  final List<Task> tasks =
      ref.watch(tasksProvider).asData?.value ?? const <Task>[];
  final List<LeaveRequest> leave =
      ref.watch(leaveCalendarProvider).asData?.value ?? const <LeaveRequest>[];

  final Map<String, List<CalendarEvent>> byDay =
      <String, List<CalendarEvent>>{};
  void add(CalendarEvent event) {
    byDay.putIfAbsent(dayKey(event.date), () => <CalendarEvent>[]).add(event);
  }

  for (final Holiday holiday in holidays) {
    // "Religious · Public holiday" — the category and the day off are
    // independent facts, and a reader wants both.
    final String kindEn = holiday.isPublic ? 'Public holiday' : 'Observance';
    final String kindNe = holiday.isPublic ? 'सार्वजनिक बिदा' : 'पर्व';
    final bool named = holiday.category != FestivalCategory.other;
    add(
      CalendarEvent(
        date: dateOnly(holiday.date),
        kind: CalendarEventKind.holiday,
        title: holiday.nameEn,
        titleNe: holiday.nameNe,
        subtitle: named ? '${holiday.category.label} · $kindEn' : kindEn,
        subtitleNe: named ? '${holiday.category.labelNe} · $kindNe' : kindNe,
        holiday: holiday,
        isPublicHoliday: holiday.isPublic,
      ),
    );
  }

  for (final Task task in tasks) {
    final DateTime? due = task.dueDate;
    if (due == null || task.done) {
      continue;
    }
    add(
      CalendarEvent(
        date: dateOnly(due),
        kind: CalendarEventKind.task,
        title: task.title,
        subtitle: task.projectName ?? '',
      ),
    );
  }

  for (final LeaveRequest request in leave) {
    if (!request.isApproved) {
      continue;
    }
    final DateTime start = dateOnly(request.startDate);
    final int span = daysBetween(start, dateOnly(request.endDate));
    for (int i = 0; i <= span; i++) {
      add(
        CalendarEvent(
          date: DateTime(start.year, start.month, start.day + i),
          kind: CalendarEventKind.leave,
          title: '${request.userName} — ${request.type.label}',
          subtitle: span == 0 ? '' : 'Day ${i + 1} of ${span + 1}',
          subtitleNe: span == 0
              ? ''
              : 'दिन ${toNepaliDigits(i + 1)} / ${toNepaliDigits(span + 1)}',
        ),
      );
    }
  }

  return byDay;
});

/// The next [limit] events from today onward, soonest first.
List<CalendarEvent> upcomingEvents(
  Map<String, List<CalendarEvent>> byDay, {
  int limit = 12,
}) {
  final DateTime today = dateOnly(DateTime.now());
  final List<CalendarEvent> all =
      <CalendarEvent>[
        for (final List<CalendarEvent> day in byDay.values)
          for (final CalendarEvent event in day)
            if (!event.date.isBefore(today)) event,
      ]..sort((CalendarEvent a, CalendarEvent b) {
        final int byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.kind.index.compareTo(b.kind.index);
      });
  return all.length <= limit ? all : all.sublist(0, limit);
}

/// The [limit] events before today, most recent first.
List<CalendarEvent> pastEvents(
  Map<String, List<CalendarEvent>> byDay, {
  int limit = 12,
}) {
  final DateTime today = dateOnly(DateTime.now());
  final List<CalendarEvent> all =
      <CalendarEvent>[
        for (final List<CalendarEvent> day in byDay.values)
          for (final CalendarEvent event in day)
            if (event.date.isBefore(today)) event,
      ]..sort((CalendarEvent a, CalendarEvent b) {
        final int byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : a.kind.index.compareTo(b.kind.index);
      });
  return all.length <= limit ? all : all.sublist(0, limit);
}

/// Holidays whose name, Nepali name, or aliases match [query], soonest first.
///
/// Searching is the point of the aliases column: "Dashain" is not the formal
/// name of any single day, so without it the search finds nothing.
List<Holiday> searchHolidays(List<Holiday> holidays, String query) {
  final List<Holiday> hits = <Holiday>[
    for (final Holiday h in holidays)
      if (h.matches(query)) h,
  ]..sort((Holiday a, Holiday b) => a.date.compareTo(b.date));
  return hits;
}

/// The holiday a day cell should print, if any.
///
/// Only holidays get their name spelled out in the grid. Task titles and
/// leave lines are far too long for a 100px cell — those stay as dots and are
/// read in the day panel. A public holiday outranks an observance.
CalendarEvent? cellHoliday(List<CalendarEvent> events) {
  CalendarEvent? found;
  for (final CalendarEvent event in events) {
    if (event.kind != CalendarEventKind.holiday) {
      continue;
    }
    if (event.isPublicHoliday) {
      return event;
    }
    found ??= event;
  }
  return found;
}
