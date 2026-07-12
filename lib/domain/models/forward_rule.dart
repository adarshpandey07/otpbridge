import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'otp_category.dart';

/// What a matched rule does with the OTP.
enum RuleAction { forward, block, requireApproval }

/// When a rule is active.
enum ScheduleKind {
  always,
  workingHours,
  weekdays,
  weekends,
  custom, // specific days-of-week + time window
  dateRange, // one-off window (e.g. "only tomorrow")
}

/// Time/date constraints for a rule. All checks are in local time.
class RuleSchedule extends Equatable {
  const RuleSchedule({
    this.kind = ScheduleKind.always,
    this.days = const {},
    this.start,
    this.end,
    this.fromDate,
    this.toDate,
  });

  final ScheduleKind kind;

  /// 1 = Monday … 7 = Sunday (DateTime.weekday convention). Used by [ScheduleKind.custom].
  final Set<int> days;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final DateTime? fromDate;
  final DateTime? toDate;

  static const RuleSchedule always = RuleSchedule();

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'days': days.toList(),
        'startMinutes': start == null ? null : start!.hour * 60 + start!.minute,
        'endMinutes': end == null ? null : end!.hour * 60 + end!.minute,
        'fromDate': fromDate?.toIso8601String(),
        'toDate': toDate?.toIso8601String(),
      };

  factory RuleSchedule.fromJson(Map<String, dynamic> json) {
    TimeOfDay? tod(num? minutes) => minutes == null
        ? null
        : TimeOfDay(hour: minutes ~/ 60, minute: (minutes % 60).toInt());
    return RuleSchedule(
      kind: ScheduleKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => ScheduleKind.always,
      ),
      days: ((json['days'] as List?) ?? const []).cast<int>().toSet(),
      start: tod(json['startMinutes'] as num?),
      end: tod(json['endMinutes'] as num?),
      fromDate: DateTime.tryParse(json['fromDate'] as String? ?? ''),
      toDate: DateTime.tryParse(json['toDate'] as String? ?? ''),
    );
  }

  RuleSchedule copyWith({
    ScheduleKind? kind,
    Set<int>? days,
    TimeOfDay? start,
    TimeOfDay? end,
    DateTime? fromDate,
    DateTime? toDate,
  }) =>
      RuleSchedule(
        kind: kind ?? this.kind,
        days: days ?? this.days,
        start: start ?? this.start,
        end: end ?? this.end,
        fromDate: fromDate ?? this.fromDate,
        toDate: toDate ?? this.toDate,
      );

  @override
  List<Object?> get props => [kind, days, start, end, fromDate, toDate];
}

/// A user-defined forwarding rule. Rules are evaluated in [sortOrder]
/// (top to bottom); the first match wins.
class ForwardRule extends Equatable {
  const ForwardRule({
    required this.id,
    required this.name,
    this.enabled = true,
    this.sortOrder = 0,
    this.categories = const {},
    this.brands = const [],
    this.senders = const [],
    this.keywords = const [],
    this.schedule = RuleSchedule.always,
    this.maxAmount,
    this.action = RuleAction.forward,
    this.recipientIds = const [],
    this.groupIds = const [],
    this.timesTriggered = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final bool enabled;
  final int sortOrder;

  /// Empty set = any category.
  final Set<OtpCategory> categories;

  /// Case-insensitive brand names ("Amazon"). Empty = any brand.
  final List<String> brands;

  /// Sender ids/prefixes ("VM-AMAZON", "AX-HDFCBK"). Empty = any sender.
  final List<String> senders;

  /// Free-text keywords that must appear in the SMS body. Empty = none required.
  final List<String> keywords;

  final RuleSchedule schedule;

  /// For financial OTPs: only auto-forward when amount <= maxAmount.
  /// Above the cap the rule escalates to manual approval.
  final double? maxAmount;

  final RuleAction action;
  final List<String> recipientIds;
  final List<String> groupIds;
  final int timesTriggered;
  final DateTime? createdAt;

  ForwardRule copyWith({
    String? name,
    bool? enabled,
    int? sortOrder,
    Set<OtpCategory>? categories,
    List<String>? brands,
    List<String>? senders,
    List<String>? keywords,
    RuleSchedule? schedule,
    double? maxAmount,
    bool clearMaxAmount = false,
    RuleAction? action,
    List<String>? recipientIds,
    List<String>? groupIds,
    int? timesTriggered,
  }) =>
      ForwardRule(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        sortOrder: sortOrder ?? this.sortOrder,
        categories: categories ?? this.categories,
        brands: brands ?? this.brands,
        senders: senders ?? this.senders,
        keywords: keywords ?? this.keywords,
        schedule: schedule ?? this.schedule,
        maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
        action: action ?? this.action,
        recipientIds: recipientIds ?? this.recipientIds,
        groupIds: groupIds ?? this.groupIds,
        timesTriggered: timesTriggered ?? this.timesTriggered,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'sortOrder': sortOrder,
        'categories': categories.map((c) => c.name).toList(),
        'brands': brands,
        'senders': senders,
        'keywords': keywords,
        'schedule': schedule.toJson(),
        'maxAmount': maxAmount,
        'action': action.name,
        'recipientIds': recipientIds,
        'groupIds': groupIds,
        'timesTriggered': timesTriggered,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory ForwardRule.fromJson(Map<String, dynamic> json) => ForwardRule(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        sortOrder: json['sortOrder'] as int? ?? 0,
        categories: ((json['categories'] as List?) ?? const [])
            .map((c) => OtpCategory.fromId(c as String?))
            .toSet(),
        brands: (json['brands'] as List?)?.cast<String>() ?? const [],
        senders: (json['senders'] as List?)?.cast<String>() ?? const [],
        keywords: (json['keywords'] as List?)?.cast<String>() ?? const [],
        schedule: json['schedule'] == null
            ? RuleSchedule.always
            : RuleSchedule.fromJson(
                Map<String, dynamic>.from(json['schedule'] as Map)),
        maxAmount: (json['maxAmount'] as num?)?.toDouble(),
        action: RuleAction.values.firstWhere(
          (a) => a.name == json['action'],
          orElse: () => RuleAction.forward,
        ),
        recipientIds:
            (json['recipientIds'] as List?)?.cast<String>() ?? const [],
        groupIds: (json['groupIds'] as List?)?.cast<String>() ?? const [],
        timesTriggered: json['timesTriggered'] as int? ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  @override
  List<Object?> get props => [
        id, name, enabled, sortOrder, categories, brands, senders, keywords,
        schedule, maxAmount, action, recipientIds, groupIds, timesTriggered,
      ];
}
