import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/nepali_calendar.dart';
import '../../../data/enums/calendar_event_kind.dart';
import '../../../data/enums/festival_category.dart';
import '../../../data/models/calendar_entry.dart';
import '../../../data/models/daily_content.dart';
import '../../../data/models/holiday.dart';
import '../../../data/models/leave_request.dart';
import '../../../data/models/muhurat.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/calendar_entries_repository.dart';
import '../../../data/repositories/daily_repository.dart';
import '../../../data/repositories/holidays_repository.dart';
import '../../../data/repositories/muhurats_repository.dart';
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

/// The saait repository.
final Provider<MuhuratsRepository> muhuratsRepositoryProvider =
    Provider<MuhuratsRepository>((ref) {
      return MuhuratsRepository(ref.watch(dioProvider));
    });

/// The personal-events repository.
final Provider<CalendarEntriesRepository> calendarEntriesRepositoryProvider =
    Provider<CalendarEntriesRepository>((ref) {
      return CalendarEntriesRepository(ref.watch(dioProvider));
    });

/// The caller's own calendar entries. Invalidate after any change.
final FutureProvider<List<CalendarEntry>> calendarEntriesProvider =
    FutureProvider<List<CalendarEntry>>((ref) {
      return ref.watch(calendarEntriesRepositoryProvider).list();
    });

/// The written-not-computed content: observances, the quote, the rashifal.
final Provider<DailyRepository> dailyRepositoryProvider =
    Provider<DailyRepository>((ref) {
      return DailyRepository(ref.watch(dioProvider));
    });

/// Every observance. They recur by month and day, so one fetch serves any date.
final FutureProvider<List<Observance>> observancesProvider =
    FutureProvider<List<Observance>>((ref) {
      return ref.watch(dailyRepositoryProvider).observances();
    });

/// The quote for a day. Null when nobody has entered any.
final quoteProvider = FutureProvider.family<Quote?, DateTime>((
  ref,
  DateTime on,
) {
  return ref.watch(dailyRepositoryProvider).quoteOfTheDay(on);
});

/// Every rashifal reading covering a day. Empty until an astrologer's readings
/// are entered — there is no formula for one.
final rashifalProvider = FutureProvider.family<List<Rashifal>, DateTime>((
  ref,
  DateTime on,
) {
  return ref.watch(dailyRepositoryProvider).rashifal(on);
});

/// The observances falling on [date], by month and day.
List<Observance> observancesOn(List<Observance> all, DateTime date) =>
    <Observance>[
      for (final Observance o in all)
        if (o.fallsOn(date)) o,
    ];

/// Published saait across the server's default window. Empty until an admin
/// enters some — they cannot be computed. Invalidate after adding or removing.
final FutureProvider<List<Muhurat>> muhuratsProvider =
    FutureProvider<List<Muhurat>>((ref) {
      return ref.watch(muhuratsRepositoryProvider).list();
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
    this.entry,
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

  /// Set only for the user's own entries, so they can be edited or deleted
  /// from the day panel.
  final CalendarEntry? entry;

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
          other.entry == entry &&
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
    entry,
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
  final List<CalendarEntry> entries =
      ref.watch(calendarEntriesProvider).asData?.value ??
      const <CalendarEntry>[];

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

  for (final CalendarEntry entry in entries) {
    // A repeating entry belongs on its next occurrence, not on the day it was
    // recorded — a birthday from 1994 goes on this year's grid. The server
    // works that out, because only it has the BS conversion table.
    final DateTime on = dateOnly(entry.shownOn);
    final int? years = entry.yearsAt(on);
    final String detail = <String>[
      entry.window(nepali: false),
      if (years != null) '$years years',
      if (entry.note.isNotEmpty) entry.note,
    ].join(' · ');
    final String detailNe = <String>[
      entry.window(nepali: true),
      if (years != null) '${toNepaliDigits(years)} वर्ष',
      if (entry.note.isNotEmpty) entry.note,
    ].join(' · ');
    add(
      CalendarEvent(
        date: on,
        kind: CalendarEventKind.personal,
        title: entry.title,
        subtitle: detail,
        subtitleNe: detailNe,
        entry: entry,
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
