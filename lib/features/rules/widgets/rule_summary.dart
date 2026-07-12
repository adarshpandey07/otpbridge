import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:otpbridge/domain/models/models.dart';

/// Plain-English formatting helpers shared by the rules list and the
/// rule editor's live schedule preview.

/// Short day names indexed by `DateTime.weekday - 1` (Mon=1 … Sun=7).
const List<String> dayAbbreviations = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];

final NumberFormat _rupees =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// "₹5,000"-style formatting for amount caps.
String formatRupees(double amount) => _rupees.format(amount);

/// A short, human-readable description of when [schedule] is active.
String scheduleSummary(BuildContext context, RuleSchedule schedule) {
  final loc = MaterialLocalizations.of(context);
  String time(TimeOfDay t) => loc.formatTimeOfDay(t);

  String window() {
    if (schedule.start == null && schedule.end == null) return 'all day';
    final start = schedule.start ?? const TimeOfDay(hour: 0, minute: 0);
    final end = schedule.end ?? const TimeOfDay(hour: 23, minute: 59);
    return '${time(start)}–${time(end)}';
  }

  switch (schedule.kind) {
    case ScheduleKind.always:
      return 'Any time';
    case ScheduleKind.workingHours:
      return 'Mon–Fri · '
          '${time(const TimeOfDay(hour: 9, minute: 0))}–'
          '${time(const TimeOfDay(hour: 18, minute: 0))}';
    case ScheduleKind.weekdays:
      return 'Weekdays';
    case ScheduleKind.weekends:
      return 'Weekends';
    case ScheduleKind.custom:
      final sorted = schedule.days.toList()..sort();
      final days = sorted.map((d) => dayAbbreviations[d - 1]).join(', ');
      return schedule.days.isEmpty
          ? 'Every day · ${window()}'
          : '$days · ${window()}';
    case ScheduleKind.dateRange:
      final df = DateFormat.MMMd();
      final from = schedule.fromDate;
      final to = schedule.toDate;
      final String range;
      if (from != null && to != null) {
        range = '${df.format(from)} – ${df.format(to)}';
      } else if (from != null) {
        range = 'From ${df.format(from)}';
      } else if (to != null) {
        range = 'Until ${df.format(to)}';
      } else {
        range = 'Any date';
      }
      final hasWindow = schedule.start != null || schedule.end != null;
      return hasWindow ? '$range · ${window()}' : range;
  }
}

/// One-line summary of a rule's conditions and destination, e.g.
/// "Amazon · 10:00 AM–7:00 PM → Rahul".
String ruleSummary(
  BuildContext context,
  ForwardRule rule,
  Map<String, Recipient> recipientsById,
) {
  final parts = <String>[];

  if (rule.brands.isNotEmpty) {
    final shown = rule.brands.take(2).join(', ');
    parts.add(
        rule.brands.length > 2 ? '$shown +${rule.brands.length - 2}' : shown);
  }
  if (rule.categories.isNotEmpty) {
    parts.add(rule.categories.length <= 2
        ? rule.categories.map((c) => c.label).join(', ')
        : '${rule.categories.length} categories');
  }
  if (rule.senders.isNotEmpty) {
    parts.add(rule.senders.length == 1
        ? rule.senders.first
        : '${rule.senders.length} senders');
  }
  if (rule.keywords.isNotEmpty) {
    parts.add(rule.keywords.length == 1
        ? '"${rule.keywords.first}"'
        : '${rule.keywords.length} keywords');
  }
  if (parts.isEmpty) parts.add('Any OTP');

  if (rule.schedule.kind != ScheduleKind.always) {
    parts.add(scheduleSummary(context, rule.schedule));
  }
  if (rule.maxAmount != null) {
    parts.add('under ${formatRupees(rule.maxAmount!)}');
  }

  var summary = parts.join(' · ');

  if (rule.action != RuleAction.block && rule.recipientIds.isNotEmpty) {
    final names = rule.recipientIds
        .map((id) => recipientsById[id]?.name)
        .whereType<String>()
        .map((n) => n.trim().split(RegExp(r'\s+')).first)
        .toList();
    if (names.isNotEmpty) {
      final extra = names.length - 1;
      summary += ' → ${names.first}${extra > 0 ? ' +$extra' : ''}';
    }
  }
  return summary;
}
