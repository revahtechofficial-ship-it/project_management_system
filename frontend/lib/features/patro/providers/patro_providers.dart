import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/nepali_calendar.dart';
import '../../../data/enums/calendar_event_kind.dart';
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
    this.holidayId,
    this.isPublicHoliday = false,
  });

  /// The Gregorian day the event falls on.
  final DateTime date;
  final CalendarEventKind kind;
  final String title;
  final String titleNe;
  final String subtitle;

  /// Set only for holidays, so admins can delete them from the day panel.
  final int? holidayId;

  /// A public holiday tints its whole day cell red; a non-public one only
  /// shows a dot.
  final bool isPublicHoliday;

  /// The title in the requested language, falling back to the other.
  String name({required bool nepali}) {
    if (nepali && titleNe.isNotEmpty) {
      return titleNe;
    }
    return title.isNotEmpty ? title : titleNe;
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
          other.holidayId == holidayId &&
          other.isPublicHoliday == isPublicHoliday;

  @override
  int get hashCode => Object.hash(
    date,
    kind,
    title,
    titleNe,
    subtitle,
    holidayId,
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
    add(
      CalendarEvent(
        date: dateOnly(holiday.date),
        kind: CalendarEventKind.holiday,
        title: holiday.nameEn,
        titleNe: holiday.nameNe,
        subtitle: holiday.isPublic ? 'Public holiday' : 'Observance',
        holidayId: holiday.id,
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

/// The event whose name a day cell should print. Holidays win over tasks and
/// leave, mirroring how a printed patro labels its days.
CalendarEvent? headlineEvent(List<CalendarEvent> events) {
  if (events.isEmpty) {
    return null;
  }
  for (final CalendarEventKind kind in CalendarEventKind.values) {
    for (final CalendarEvent event in events) {
      if (event.kind == kind) {
        return event;
      }
    }
  }
  return events.first;
}
