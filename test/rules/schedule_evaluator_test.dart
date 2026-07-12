import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:otpbridge/data/rules/schedule_evaluator.dart';
import 'package:otpbridge/domain/models/models.dart';

void main() {
  const evaluator = ScheduleEvaluator();

  // Fixed reference dates (local time).
  final monday0859 = DateTime(2026, 7, 6, 8, 59);
  final monday1000 = DateTime(2026, 7, 6, 10, 0);
  final monday1800 = DateTime(2026, 7, 6, 18, 0);
  final monday1830 = DateTime(2026, 7, 6, 18, 30);
  final saturday1000 = DateTime(2026, 7, 11, 10, 0);
  final sunday2300 = DateTime(2026, 7, 12, 23, 0);

  test('reference dates are the weekdays the suite assumes', () {
    expect(monday1000.weekday, DateTime.monday);
    expect(saturday1000.weekday, DateTime.saturday);
    expect(sunday2300.weekday, DateTime.sunday);
  });

  group('always', () {
    test('is active at any moment', () {
      expect(evaluator.isActive(RuleSchedule.always, monday1000), isTrue);
      expect(evaluator.isActive(RuleSchedule.always, sunday2300), isTrue);
    });
  });

  group('workingHours (Mon-Fri 09:00-18:00)', () {
    const schedule = RuleSchedule(kind: ScheduleKind.workingHours);

    test('active on a weekday inside the window', () {
      expect(evaluator.isActive(schedule, monday1000), isTrue);
      expect(evaluator.isActive(schedule, monday1800), isTrue,
          reason: '18:00 is inclusive');
    });

    test('inactive outside hours or on weekends', () {
      expect(evaluator.isActive(schedule, monday0859), isFalse);
      expect(evaluator.isActive(schedule, monday1830), isFalse);
      expect(evaluator.isActive(schedule, saturday1000), isFalse);
      expect(evaluator.isActive(schedule, sunday2300), isFalse);
    });
  });

  group('weekdays', () {
    const schedule = RuleSchedule(kind: ScheduleKind.weekdays);

    test('active Mon-Fri at any time, inactive on weekends', () {
      expect(evaluator.isActive(schedule, monday1000), isTrue);
      expect(evaluator.isActive(schedule, monday1830), isTrue);
      expect(evaluator.isActive(schedule, saturday1000), isFalse);
      expect(evaluator.isActive(schedule, sunday2300), isFalse);
    });
  });

  group('weekends', () {
    const schedule = RuleSchedule(kind: ScheduleKind.weekends);

    test('active Sat-Sun at any time, inactive on weekdays', () {
      expect(evaluator.isActive(schedule, saturday1000), isTrue);
      expect(evaluator.isActive(schedule, sunday2300), isTrue);
      expect(evaluator.isActive(schedule, monday1000), isFalse);
    });
  });

  group('custom', () {
    test('matches day-of-week and time window together', () {
      const schedule = RuleSchedule(
        kind: ScheduleKind.custom,
        days: {DateTime.sunday},
        start: TimeOfDay(hour: 22, minute: 0),
        end: TimeOfDay(hour: 23, minute: 30),
      );
      expect(evaluator.isActive(schedule, sunday2300), isTrue);
      expect(evaluator.isActive(schedule, DateTime(2026, 7, 12, 21, 0)),
          isFalse, reason: 'right day, before the window');
      expect(evaluator.isActive(schedule, DateTime(2026, 7, 6, 23, 0)),
          isFalse, reason: 'right time, wrong day (Monday)');
    });

    test('null start/end means any time on the listed days', () {
      const schedule = RuleSchedule(
        kind: ScheduleKind.custom,
        days: {DateTime.monday},
      );
      expect(evaluator.isActive(schedule, monday0859), isTrue);
      expect(evaluator.isActive(schedule, monday1830), isTrue);
      expect(evaluator.isActive(schedule, sunday2300), isFalse);
    });

    test('start == end is treated as all-day', () {
      const schedule = RuleSchedule(
        kind: ScheduleKind.custom,
        days: {DateTime.monday},
        start: TimeOfDay(hour: 10, minute: 0),
        end: TimeOfDay(hour: 10, minute: 0),
      );
      expect(evaluator.isActive(schedule, monday0859), isTrue);
      expect(evaluator.isActive(schedule, monday1830), isTrue);
    });

    test('empty day set means any day (window still applies)', () {
      const schedule = RuleSchedule(
        kind: ScheduleKind.custom,
        start: TimeOfDay(hour: 9, minute: 0),
        end: TimeOfDay(hour: 12, minute: 0),
      );
      expect(evaluator.isActive(schedule, monday1000), isTrue);
      expect(evaluator.isActive(schedule, saturday1000), isTrue);
      expect(evaluator.isActive(schedule, sunday2300), isFalse);
    });

    test('window crossing midnight wraps around', () {
      const schedule = RuleSchedule(
        kind: ScheduleKind.custom,
        start: TimeOfDay(hour: 22, minute: 0),
        end: TimeOfDay(hour: 6, minute: 0),
      );
      expect(evaluator.isActive(schedule, sunday2300), isTrue);
      expect(evaluator.isActive(schedule, DateTime(2026, 7, 6, 5, 30)), isTrue);
      expect(evaluator.isActive(schedule, monday1000), isFalse);
    });
  });

  group('dateRange', () {
    test('dates are inclusive at date granularity', () {
      final schedule = RuleSchedule(
        kind: ScheduleKind.dateRange,
        fromDate: DateTime(2026, 7, 10),
        toDate: DateTime(2026, 7, 12),
      );
      expect(evaluator.isActive(schedule, saturday1000), isTrue);
      expect(evaluator.isActive(schedule, sunday2300), isTrue,
          reason: 'toDate day itself is inside the range');
      expect(evaluator.isActive(schedule, monday1000), isFalse,
          reason: 'July 6 is before fromDate');
      expect(evaluator.isActive(schedule, DateTime(2026, 7, 13, 0, 1)),
          isFalse, reason: 'day after toDate');
    });

    test('daily time window also applies when set', () {
      final schedule = RuleSchedule(
        kind: ScheduleKind.dateRange,
        fromDate: DateTime(2026, 7, 10),
        toDate: DateTime(2026, 7, 12),
        start: const TimeOfDay(hour: 9, minute: 0),
        end: const TimeOfDay(hour: 12, minute: 0),
      );
      expect(evaluator.isActive(schedule, saturday1000), isTrue);
      expect(evaluator.isActive(schedule, sunday2300), isFalse,
          reason: 'inside the date range but outside the daily window');
    });

    test('null bounds are open-ended', () {
      final noLowerBound = RuleSchedule(
        kind: ScheduleKind.dateRange,
        toDate: DateTime(2026, 7, 6),
      );
      expect(evaluator.isActive(noLowerBound, monday1000), isTrue);
      expect(evaluator.isActive(noLowerBound, sunday2300), isFalse);

      final noUpperBound = RuleSchedule(
        kind: ScheduleKind.dateRange,
        fromDate: DateTime(2026, 7, 12),
      );
      expect(evaluator.isActive(noUpperBound, sunday2300), isTrue);
      expect(evaluator.isActive(noUpperBound, monday1000), isFalse);
    });
  });
}
