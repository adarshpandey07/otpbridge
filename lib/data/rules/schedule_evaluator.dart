import 'package:flutter/material.dart' show TimeOfDay;

import 'package:otpbridge/domain/models/models.dart';

/// Decides whether a [RuleSchedule] is active at a given moment.
///
/// All comparisons use the local wall-clock fields of `now`
/// (weekday, hour, minute, calendar date). Pure and deterministic.
class ScheduleEvaluator {
  const ScheduleEvaluator();

  /// Working hours window: Mon–Fri, 09:00–18:00 inclusive.
  static const TimeOfDay _workStart = TimeOfDay(hour: 9, minute: 0);
  static const TimeOfDay _workEnd = TimeOfDay(hour: 18, minute: 0);

  /// Returns true when [schedule] is active at [now].
  bool isActive(RuleSchedule schedule, DateTime now) {
    switch (schedule.kind) {
      case ScheduleKind.always:
        return true;
      case ScheduleKind.workingHours:
        return _isWeekday(now) && _inTimeWindow(now, _workStart, _workEnd);
      case ScheduleKind.weekdays:
        return _isWeekday(now);
      case ScheduleKind.weekends:
        return !_isWeekday(now);
      case ScheduleKind.custom:
        // Empty day set is treated as "any day" (consistent with the
        // empty-means-any convention used across rule conditions).
        final dayOk =
            schedule.days.isEmpty || schedule.days.contains(now.weekday);
        return dayOk && _inTimeWindow(now, schedule.start, schedule.end);
      case ScheduleKind.dateRange:
        return _inDateRange(now, schedule.fromDate, schedule.toDate) &&
            _inTimeWindow(now, schedule.start, schedule.end);
    }
  }

  bool _isWeekday(DateTime now) => now.weekday <= DateTime.friday;

  /// True when `now` falls inside the daily [start, end] window (inclusive).
  ///
  /// - Both null → any time.
  /// - A null start is treated as 00:00; a null end as 23:59.
  /// - start == end → all-day.
  /// - start > end (crosses midnight) → overnight window (e.g. 22:00–06:00).
  bool _inTimeWindow(DateTime now, TimeOfDay? start, TimeOfDay? end) {
    if (start == null && end == null) return true;
    final startMin = start == null ? 0 : start.hour * 60 + start.minute;
    final endMin = end == null ? 23 * 60 + 59 : end.hour * 60 + end.minute;
    if (startMin == endMin) return true; // All-day.
    final nowMin = now.hour * 60 + now.minute;
    if (startMin <= endMin) {
      return nowMin >= startMin && nowMin <= endMin;
    }
    // Window wraps past midnight.
    return nowMin >= startMin || nowMin <= endMin;
  }

  /// True when `now`'s calendar date is within [from, to] inclusive.
  /// A null bound is open-ended on that side.
  bool _inDateRange(DateTime now, DateTime? from, DateTime? to) {
    final today = DateTime(now.year, now.month, now.day);
    if (from != null) {
      final first = DateTime(from.year, from.month, from.day);
      if (today.isBefore(first)) return false;
    }
    if (to != null) {
      final last = DateTime(to.year, to.month, to.day);
      if (today.isAfter(last)) return false;
    }
    return true;
  }
}
