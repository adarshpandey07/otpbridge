import 'package:flutter/material.dart' show TimeOfDay;

import '../../domain/models/forward_rule.dart';
import '../../domain/models/incoming_sms.dart';
import '../../domain/models/otp_category.dart';
import '../../domain/models/recipient.dart';
import '../../domain/services/service_contracts.dart';

/// A rule assembled from a natural-language sentence, plus what (if anything)
/// still needs the user's confirmation.
class RuleDraft {
  const RuleDraft({
    required this.suggestedName,
    required this.categories,
    required this.brands,
    required this.recipientIds,
    required this.schedule,
    required this.action,
    required this.confidence,
    required this.explanation,
    this.missing = const [],
  });

  final String suggestedName;
  final Set<OtpCategory> categories;
  final List<String> brands;
  final List<String> recipientIds;
  final RuleSchedule schedule;
  final RuleAction action;
  final double confidence;
  final String explanation;

  /// Slots the parser could not fill from the text: e.g. 'recipient'.
  final List<String> missing;

  ForwardRule toRule({required String id, int sortOrder = 0, DateTime? now}) =>
      ForwardRule(
        id: id,
        name: suggestedName,
        sortOrder: sortOrder,
        categories: categories,
        brands: brands,
        schedule: schedule,
        action: action,
        recipientIds: recipientIds,
        createdAt: now,
      );
}

/// Deterministic, offline natural-language → rule parser.
///
/// WHY ON-DEVICE HEURISTICS INSTEAD OF A BUNDLED LLM: SMS-automation intents
/// are short and highly patterned ("forward `brand/category` to `person`
/// `when`"). Slot-filling over the existing brand catalog + a small schedule
/// grammar hits these reliably at ~0ms, ~0 battery, ~0 MB — versus bundling a
/// 1–3 GB model that many mid-range phones can't run. The same [parse] seam
/// can defer to a cloud LLM for fuzzier phrasing when the device is online and
/// confidence is low; that's an enhancement, not a dependency.
class NaturalLanguageRuleParser {
  NaturalLanguageRuleParser(this._classifier);

  final ClassificationEngine _classifier;

  RuleDraft parse(String text, {required List<Recipient> recipients}) {
    final lower = text.toLowerCase();

    // 1. Brand + category via the existing classifier (treat text as a body).
    final probe = _classifier.classifySync(
      IncomingSms(id: 'nl', sender: '', body: text, receivedAt: DateTime(2000)),
    );
    final brands = <String>[];
    final categories = <OtpCategory>{};
    if (probe.brand != null) brands.add(probe.brand!);
    if (probe.category != OtpCategory.unknown) categories.add(probe.category);

    // Also match high-level group words the classifier might miss.
    for (final group in CategoryGroup.values) {
      if (lower.contains(group.label.toLowerCase().split(' ').first)) {
        categories.addAll(group.categories);
      }
    }
    // Common domain words → categories.
    _keywordCategories.forEach((kw, cat) {
      if (lower.contains(kw)) categories.add(cat);
    });

    // 2. Recipient matching by name.
    final recipientIds = <String>[];
    String? recipientName;
    for (final r in recipients) {
      final name = r.name.toLowerCase();
      if (name.isEmpty) continue;
      final firstName = name.split(RegExp(r'\s+')).first;
      if (lower.contains(name) || lower.contains(firstName)) {
        recipientIds.add(r.id);
        recipientName ??= r.name;
      }
    }

    // 3. Action.
    final action = _parseAction(lower);

    // 4. Schedule.
    final schedule = _parseSchedule(lower);

    // 5. Name + explanation.
    final subject = brands.isNotEmpty
        ? brands.first
        : (categories.isNotEmpty ? categories.first.label : 'All');
    final target = recipientName ?? 'a recipient';
    final name = action == RuleAction.block
        ? 'Block $subject'
        : '$subject → ${recipientName ?? "…"}';

    final missing = <String>[
      if (action != RuleAction.block && recipientIds.isEmpty) 'recipient',
      if (brands.isEmpty && categories.isEmpty) 'what',
    ];

    var confidence = 0.5;
    if (brands.isNotEmpty || categories.isNotEmpty) confidence += 0.25;
    if (recipientIds.isNotEmpty || action == RuleAction.block) {
      confidence += 0.2;
    }
    confidence = confidence.clamp(0.0, 0.98);

    final actionWord = switch (action) {
      RuleAction.forward => 'Forward',
      RuleAction.block => 'Block',
      RuleAction.requireApproval => 'Ask before forwarding',
    };
    final explanation = action == RuleAction.block
        ? 'Block $subject messages'
        : '$actionWord $subject messages to $target ${_scheduleWords(schedule)}'
            .trim();

    return RuleDraft(
      suggestedName: name,
      categories: categories,
      brands: brands,
      recipientIds: recipientIds,
      schedule: schedule,
      action: action,
      confidence: confidence,
      explanation: explanation,
      missing: missing,
    );
  }

  static const Map<String, OtpCategory> _keywordCategories = {
    'bank': OtpCategory.bankingTransaction,
    'transaction': OtpCategory.bankingTransaction,
    'upi': OtpCategory.upi,
    'grocery': OtpCategory.grocery,
    'groceries': OtpCategory.grocery,
    'food': OtpCategory.foodDelivery,
    'order': OtpCategory.ecommerce,
    'delivery': OtpCategory.courier,
    'courier': OtpCategory.courier,
    'tax': OtpCategory.tax,
    'income tax': OtpCategory.tax,
    'gst': OtpCategory.tax,
    'insurance': OtpCategory.insurance,
    'investment': OtpCategory.investment,
    'mutual fund': OtpCategory.investment,
    'stock': OtpCategory.investment,
    'recharge': OtpCategory.recharge,
    'bill': OtpCategory.utilityBills,
    'electricity': OtpCategory.utilityBills,
    'travel': OtpCategory.travel,
    'flight': OtpCategory.travel,
    'hotel': OtpCategory.hotel,
    'cab': OtpCategory.rideBooking,
    'ride': OtpCategory.rideBooking,
  };

  RuleAction _parseAction(String lower) {
    if (RegExp(r"\b(block|never|don'?t forward|do not forward|stop)\b")
        .hasMatch(lower)) {
      return RuleAction.block;
    }
    if (RegExp(r'\b(ask|approve|approval|confirm|check with me|verify with me)\b')
        .hasMatch(lower)) {
      return RuleAction.requireApproval;
    }
    return RuleAction.forward;
  }

  RuleSchedule _parseSchedule(String lower) {
    if (RegExp(r'\b(office|working|business)\s*hours?\b').hasMatch(lower)) {
      return const RuleSchedule(kind: ScheduleKind.workingHours);
    }
    if (lower.contains('weekend')) {
      return const RuleSchedule(kind: ScheduleKind.weekends);
    }
    if (lower.contains('weekday')) {
      return const RuleSchedule(kind: ScheduleKind.weekdays);
    }
    // "10am to 7pm", "10 am - 7 pm"
    final window = RegExp(
            r'(\d{1,2})\s*(?::(\d{2}))?\s*(am|pm)?\s*(?:-|to|until|till)\s*(\d{1,2})\s*(?::(\d{2}))?\s*(am|pm)?')
        .firstMatch(lower);
    if (window != null) {
      final start = _parseTime(
          window.group(1), window.group(2), window.group(3));
      final end =
          _parseTime(window.group(4), window.group(5), window.group(6));
      if (start != null && end != null) {
        return RuleSchedule(
          kind: ScheduleKind.custom,
          days: const {1, 2, 3, 4, 5, 6, 7},
          start: start,
          end: end,
        );
      }
    }
    return const RuleSchedule(kind: ScheduleKind.always);
  }

  TimeOfDay? _parseTime(String? h, String? m, String? ampm) {
    if (h == null) return null;
    var hour = int.tryParse(h);
    if (hour == null) return null;
    final minute = int.tryParse(m ?? '0') ?? 0;
    if (ampm == 'pm' && hour < 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _scheduleWords(RuleSchedule s) => switch (s.kind) {
        ScheduleKind.always => 'anytime',
        ScheduleKind.workingHours => 'during office hours',
        ScheduleKind.weekdays => 'on weekdays',
        ScheduleKind.weekends => 'on weekends',
        ScheduleKind.custom => 'in your chosen hours',
        ScheduleKind.dateRange => 'in your chosen dates',
      };
}
