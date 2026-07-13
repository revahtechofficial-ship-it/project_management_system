import 'package:flutter_test/flutter_test.dart';
import 'package:revahms_web/data/enums/calendar_entry_kind.dart';
import 'package:revahms_web/data/models/calendar_entry.dart';

void main() {
  group('CalendarEntry JSON', () {
    Map<String, dynamic> json() => <String, dynamic>{
      'id': 4,
      'date': '1994-07-09',
      'kind': 'birthday',
      'title': 'Ramesh',
      'note': 'Loves momo',
      'start_time': '',
      'end_time': '',
      'repeat_in': 'bs',
      'remind_days': 1,
      'next_occurs': '2026-07-09',
    };

    test('round-trips', () {
      expect(CalendarEntry.fromJson(json()).toJson(), json());
    });

    test('survives a payload with only the required keys', () {
      final CalendarEntry bare = CalendarEntry.fromJson(<String, dynamic>{
        'id': 1,
        'date': '2026-01-01',
      });
      expect(bare.kind, CalendarEntryKind.note);
      expect(bare.repeatIn, RepeatIn.none);
      expect(bare.remindDays, isNull);
      expect(bare.nextOccurs, isNull);
      expect(bare.isAllDay, isTrue);
    });

    test('an unknown kind or repeat mode degrades rather than throwing', () {
      final CalendarEntry odd = CalendarEntry.fromJson(<String, dynamic>{
        'id': 1,
        'date': '2026-01-01',
        'kind': 'coronation',
        'repeat_in': 'lunar',
      });
      expect(odd.kind, CalendarEntryKind.note);
      expect(odd.repeatIn, RepeatIn.none);
    });
  });

  group('where an entry lands on the grid', () {
    test('a repeating entry shows on its next occurrence, not its own day', () {
      // A birthday recorded in 1994 belongs on this year's calendar, not on
      // 1994's. The server computes next_occurs, because a BS recurrence needs
      // the conversion table.
      final CalendarEntry birthday = CalendarEntry(
        id: 1,
        date: DateTime(1994, 7, 9),
        kind: CalendarEntryKind.birthday,
        repeatIn: RepeatIn.bs,
        nextOccurs: DateTime(2026, 7, 9),
      );
      expect(birthday.shownOn, DateTime(2026, 7, 9));
    });

    test('a one-off shows on its own day', () {
      final CalendarEntry meeting = CalendarEntry(
        id: 1,
        date: DateTime(2026, 7, 9),
        kind: CalendarEntryKind.meeting,
      );
      expect(meeting.shownOn, DateTime(2026, 7, 9));
    });

    test('a repeating entry with no next_occurs falls back to its own day', () {
      // The server has not swept it yet. Better on the wrong day than nowhere.
      final CalendarEntry unswept = CalendarEntry(
        id: 1,
        date: DateTime(1994, 7, 9),
        repeatIn: RepeatIn.bs,
      );
      expect(unswept.shownOn, DateTime(1994, 7, 9));
    });
  });

  group('how old', () {
    test('counts the years for a repeating entry', () {
      final CalendarEntry birthday = CalendarEntry(
        id: 1,
        date: DateTime(1994, 7, 9),
        kind: CalendarEntryKind.birthday,
        repeatIn: RepeatIn.bs,
        nextOccurs: DateTime(2026, 7, 9),
      );
      expect(birthday.yearsAt(DateTime(2026, 7, 9)), 32);
    });

    test('says nothing for a one-off, or in the year it was recorded', () {
      final CalendarEntry meeting = CalendarEntry(
        id: 1,
        date: DateTime(2026, 7, 9),
        kind: CalendarEntryKind.meeting,
      );
      expect(meeting.yearsAt(DateTime(2026, 7, 9)), isNull);

      final CalendarEntry thisYear = CalendarEntry(
        id: 2,
        date: DateTime(2026, 7, 9),
        kind: CalendarEntryKind.birthday,
        repeatIn: RepeatIn.bs,
        nextOccurs: DateTime(2026, 7, 9),
      );
      // "0 years" is not worth printing.
      expect(thisYear.yearsAt(DateTime(2026, 7, 9)), isNull);
    });
  });

  group('the window', () {
    test('reads all-day, a single time, or a span', () {
      final CalendarEntry allDay = CalendarEntry(id: 1, date: _d);
      expect(allDay.window(nepali: false), 'All day');
      expect(allDay.window(nepali: true), 'दिनभर');

      final CalendarEntry atTime = CalendarEntry(
        id: 2,
        date: _d,
        startTime: '09:15',
      );
      expect(atTime.window(nepali: false), '09:15');

      final CalendarEntry span = CalendarEntry(
        id: 3,
        date: _d,
        startTime: '09:15',
        endTime: '10:00',
      );
      expect(span.window(nepali: false), '09:15 – 10:00');
    });
  });

  group('repeat modes', () {
    test('birthdays and anniversaries are the ones that recur', () {
      expect(CalendarEntryKind.birthday.repeatsByDefault, isTrue);
      expect(CalendarEntryKind.anniversary.repeatsByDefault, isTrue);
      expect(CalendarEntryKind.meeting.repeatsByDefault, isFalse);
      expect(CalendarEntryKind.note.repeatsByDefault, isFalse);
    });

    test('only none does not repeat', () {
      expect(RepeatIn.none.repeats, isFalse);
      expect(RepeatIn.ad.repeats, isTrue);
      expect(RepeatIn.bs.repeats, isTrue);
    });

    test('each mode says which calendar it means', () {
      // The whole point: these are different days, and the UI has to say so.
      expect(RepeatIn.ad.hint, contains('Gregorian'));
      expect(RepeatIn.bs.hint, contains('BS'));
    });
  });
}

final DateTime _d = DateTime(2026, 7, 9);
