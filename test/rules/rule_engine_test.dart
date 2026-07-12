import 'package:flutter_test/flutter_test.dart';
import 'package:otpbridge/data/rules/rule_engine_impl.dart';
import 'package:otpbridge/domain/models/models.dart';

void main() {
  final engine = DefaultRuleEngine();

  // Monday 2026-07-06 10:00 local — inside working hours.
  final mondayMorning = DateTime(2026, 7, 6, 10, 0);
  const settings = AppSettings(); // cap 5000, highRiskRequiresApproval true.

  SmsClassification classify({
    String sender = 'AX-HDFCBK',
    String body = 'Your OTP is 123456. Do not share it.',
    OtpCategory category = OtpCategory.ecommerce,
    String? brand,
    double? amount,
  }) =>
      SmsClassification(
        sms: IncomingSms(
          id: 'sms-1',
          sender: sender,
          body: body,
          receivedAt: DateTime(2026, 7, 6, 9, 59),
        ),
        category: category,
        confidence: 0.92,
        otp: '123456',
        brand: brand,
        amount: amount,
      );

  ForwardRule rule({
    String id = 'r1',
    String name = 'Rule',
    bool enabled = true,
    int sortOrder = 0,
    Set<OtpCategory> categories = const {},
    List<String> brands = const [],
    List<String> senders = const [],
    List<String> keywords = const [],
    RuleSchedule schedule = RuleSchedule.always,
    double? maxAmount,
    RuleAction action = RuleAction.forward,
    List<String> recipientIds = const ['rec-1'],
  }) =>
      ForwardRule(
        id: id,
        name: name,
        enabled: enabled,
        sortOrder: sortOrder,
        categories: categories,
        brands: brands,
        senders: senders,
        keywords: keywords,
        schedule: schedule,
        maxAmount: maxAmount,
        action: action,
        recipientIds: recipientIds,
      );

  RuleDecision evaluate(
    List<ForwardRule> rules, {
    SmsClassification? classification,
    AppSettings appSettings = settings,
    DateTime? now,
  }) =>
      engine.evaluate(
        classification: classification ?? classify(),
        rules: rules,
        settings: appSettings,
        now: now ?? mondayMorning,
      );

  group('ordering', () {
    test('first matching enabled rule wins', () {
      final decision = evaluate([
        rule(id: 'top', action: RuleAction.block),
        rule(id: 'bottom', action: RuleAction.forward),
      ]);
      expect(decision.kind, DecisionKind.block);
      expect(decision.rule?.id, 'top');
    });

    test('disabled rules are skipped', () {
      final decision = evaluate([
        rule(id: 'off', enabled: false, action: RuleAction.block),
        rule(id: 'on', action: RuleAction.forward),
      ]);
      expect(decision.kind, DecisionKind.forward);
      expect(decision.rule?.id, 'on');
    });

    test('non-matching earlier rule falls through to a later one', () {
      final decision = evaluate([
        rule(id: 'banking-only', categories: {OtpCategory.bankingLogin}),
        rule(id: 'catch-all'),
      ]);
      expect(decision.rule?.id, 'catch-all');
    });
  });

  group('condition matching', () {
    test('category set must contain the classification category', () {
      final matched = evaluate(
        [rule(categories: {OtpCategory.ecommerce, OtpCategory.grocery})],
        classification: classify(category: OtpCategory.ecommerce),
      );
      expect(matched.kind, DecisionKind.forward);

      final unmatched = evaluate(
        [rule(categories: {OtpCategory.grocery})],
        classification: classify(category: OtpCategory.ecommerce),
      );
      expect(unmatched.kind, DecisionKind.noMatch);
    });

    test('empty categories means any category', () {
      final decision = evaluate(
        [rule()],
        classification: classify(category: OtpCategory.telecom),
      );
      expect(decision.kind, DecisionKind.forward);
    });

    test('brand match is case-insensitive', () {
      final matched = evaluate(
        [rule(brands: ['Amazon'])],
        classification: classify(brand: 'AMAZON'),
      );
      expect(matched.kind, DecisionKind.forward);

      final unmatched = evaluate(
        [rule(brands: ['Amazon'])],
        classification: classify(brand: 'Flipkart'),
      );
      expect(unmatched.kind, DecisionKind.noMatch);
    });

    test('brand condition fails when the classification has no brand', () {
      final decision = evaluate(
        [rule(brands: ['Amazon'])],
        classification: classify(brand: null),
      );
      expect(decision.kind, DecisionKind.noMatch);
    });

    test('sender matches case-insensitively by substring or prefix', () {
      final bySubstring = evaluate(
        [rule(senders: ['hdfcbk'])],
        classification: classify(sender: 'AX-HDFCBK'),
      );
      expect(bySubstring.kind, DecisionKind.forward);

      final byPrefix = evaluate(
        [rule(senders: ['AX-'])],
        classification: classify(sender: 'ax-hdfcbk'),
      );
      expect(byPrefix.kind, DecisionKind.forward);

      final unmatched = evaluate(
        [rule(senders: ['VM-AMAZON'])],
        classification: classify(sender: 'AX-HDFCBK'),
      );
      expect(unmatched.kind, DecisionKind.noMatch);
    });

    test('every keyword must appear in the body, case-insensitively', () {
      final matched = evaluate(
        [rule(keywords: ['OTP', 'share'])],
        classification:
            classify(body: 'Your otp is 123456. Do not SHARE it.'),
      );
      expect(matched.kind, DecisionKind.forward);

      final unmatched = evaluate(
        [rule(keywords: ['OTP', 'refund'])],
        classification: classify(body: 'Your OTP is 123456.'),
      );
      expect(unmatched.kind, DecisionKind.noMatch);
    });

    test('inactive schedule prevents a match', () {
      final decision = evaluate(
        [
          rule(
            id: 'weekend-only',
            schedule: const RuleSchedule(kind: ScheduleKind.weekends),
          ),
          rule(id: 'anytime'),
        ],
        now: mondayMorning,
      );
      expect(decision.rule?.id, 'anytime');
    });

    test('active schedule allows the match', () {
      final decision = evaluate(
        [
          rule(
            id: 'working-hours',
            schedule: const RuleSchedule(kind: ScheduleKind.workingHours),
          ),
        ],
        now: mondayMorning,
      );
      expect(decision.kind, DecisionKind.forward);
      expect(decision.rule?.id, 'working-hours');
    });
  });

  group('actions', () {
    test('block action produces a block decision with the rule attached', () {
      final decision = evaluate([rule(name: 'No spam', action: RuleAction.block)]);
      expect(decision.kind, DecisionKind.block);
      expect(decision.rule?.name, 'No spam');
    });

    test('requireApproval action produces requireApproval', () {
      final decision =
          evaluate([rule(action: RuleAction.requireApproval)]);
      expect(decision.kind, DecisionKind.requireApproval);
    });

    test('forward passes through the rule recipientIds', () {
      final decision = evaluate([
        rule(recipientIds: ['rec-1', 'rec-2']),
      ]);
      expect(decision.kind, DecisionKind.forward);
      expect(decision.recipientIds, ['rec-1', 'rec-2']);
    });
  });

  group('security escalation', () {
    test('amount above rule maxAmount escalates to approval', () {
      final decision = evaluate(
        [rule(maxAmount: 2000)],
        classification: classify(amount: 3500),
      );
      expect(decision.kind, DecisionKind.requireApproval);
      expect(decision.reason, contains('₹3500'));
      expect(decision.reason, contains("₹2000 limit"));
      expect(decision.rule, isNotNull);
      expect(decision.recipientIds, ['rec-1']);
    });

    test('amount at or below rule maxAmount forwards normally', () {
      final decision = evaluate(
        [rule(maxAmount: 2000)],
        classification: classify(amount: 2000),
      );
      expect(decision.kind, DecisionKind.forward);
    });

    test('financial amount above the global banking cap escalates', () {
      final decision = evaluate(
        [rule(categories: {OtpCategory.upi})],
        classification: classify(category: OtpCategory.upi, amount: 8000),
      );
      expect(decision.kind, DecisionKind.requireApproval);
      expect(decision.reason, contains('₹8000'));
      expect(decision.reason, contains('₹5000 auto-forward cap'));
    });

    test('banking cap ignores non-financial categories', () {
      final decision = evaluate(
        [rule()],
        classification:
            classify(category: OtpCategory.ecommerce, amount: 99999),
      );
      expect(decision.kind, DecisionKind.forward);
    });

    test('high-risk category via a broad rule escalates to approval', () {
      final decision = evaluate(
        [rule()], // Empty categories = matched broadly.
        classification: classify(category: OtpCategory.upi),
      );
      expect(decision.kind, DecisionKind.requireApproval);
      expect(decision.reason, 'High-risk OTP requires approval');
    });

    test('explicitly named high-risk category is allowed to forward', () {
      final decision = evaluate(
        [rule(categories: {OtpCategory.upi})],
        classification: classify(category: OtpCategory.upi),
      );
      expect(decision.kind, DecisionKind.forward);
    });

    test('high-risk escalation is off when the setting is disabled', () {
      final decision = evaluate(
        [rule()],
        classification: classify(category: OtpCategory.creditCard),
        appSettings: const AppSettings(highRiskRequiresApproval: false),
      );
      expect(decision.kind, DecisionKind.forward);
    });

    test('rule maxAmount reason takes precedence over cap and high-risk', () {
      final decision = evaluate(
        [rule(maxAmount: 1000)], // Broad rule, so high-risk also applies.
        classification: classify(category: OtpCategory.upi, amount: 8000),
      );
      expect(decision.kind, DecisionKind.requireApproval);
      expect(decision.reason, contains("this rule's ₹1000 limit"));
    });

    test('banking cap reason takes precedence over high-risk', () {
      final decision = evaluate(
        [rule()], // Broad rule, no maxAmount.
        classification: classify(category: OtpCategory.upi, amount: 8000),
      );
      expect(decision.kind, DecisionKind.requireApproval);
      expect(decision.reason, contains('auto-forward cap'));
    });

    test('block and requireApproval actions are not affected by amounts', () {
      final decision = evaluate(
        [rule(action: RuleAction.block, maxAmount: 100)],
        classification: classify(category: OtpCategory.upi, amount: 8000),
      );
      expect(decision.kind, DecisionKind.block);
    });
  });

  group('no match', () {
    test('empty rule list returns noMatch', () {
      final decision = evaluate(const []);
      expect(decision.kind, DecisionKind.noMatch);
      expect(decision.rule, isNull);
      expect(decision.reason, 'No rule matched');
    });

    test('all rules failing conditions returns noMatch', () {
      final decision = evaluate(
        [
          rule(categories: {OtpCategory.travel}),
          rule(enabled: false),
          rule(schedule: const RuleSchedule(kind: ScheduleKind.weekends)),
        ],
        classification: classify(category: OtpCategory.ecommerce),
      );
      expect(decision.kind, DecisionKind.noMatch);
    });
  });
}
