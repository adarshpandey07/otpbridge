import 'package:flutter_test/flutter_test.dart';
import 'package:otpbridge/data/suggestions/suggestion_engine.dart';
import 'package:otpbridge/domain/models/models.dart';

DetectedService svc(String brand, OtpCategory category, int count) =>
    DetectedService(
      brand: brand,
      category: category,
      sampleSender: 'VM-${brand.toUpperCase().replaceAll(' ', '')}',
      messageCount: count,
      lastSeen: DateTime(2026, 7, 10),
    );

DateTime fixedClock() => DateTime(2026, 7, 12, 9, 30);

void main() {
  const engine = SuggestionEngine();
  const recipients = [
    Recipient(id: 'r1', name: 'Rahul', phone: '+919876543210'),
    Recipient(id: 'r2', name: 'Priya', phone: '+919812345678'),
  ];

  group('SuggestionEngine.generate', () {
    test('no rules → suggests per service, most-messaged first', () {
      final out = engine.generate(
        detectedServices: [
          svc('Swiggy', OtpCategory.foodDelivery, 5),
          svc('Amazon', OtpCategory.ecommerce, 12),
        ],
        existingRules: const [],
        recipients: recipients,
        clock: fixedClock,
      );

      expect(out, hasLength(2));

      final first = out.first;
      expect(first.title, 'Forward Amazon updates?');
      expect(first.body, contains('12 messages'));
      expect(first.body, contains('Amazon'));
      expect(first.body, contains('Rahul')); // first recipient pre-filled
      expect(first.proposedRule.brands, ['Amazon']);
      expect(first.proposedRule.categories, {OtpCategory.ecommerce});
      expect(first.proposedRule.action, RuleAction.forward);
      expect(first.proposedRule.recipientIds, ['r1']);
      expect(first.proposedRule.enabled, isTrue);

      expect(out[1].proposedRule.brands, ['Swiggy']);
    });

    test('uses the injected clock, never DateTime.now()', () {
      final out = engine.generate(
        detectedServices: [svc('Amazon', OtpCategory.ecommerce, 3)],
        existingRules: const [],
        recipients: recipients,
        clock: fixedClock,
      );
      expect(out.single.createdAt, DateTime(2026, 7, 12, 9, 30));
      expect(out.single.proposedRule.createdAt, DateTime(2026, 7, 12, 9, 30));
    });

    test('enabled rule covering the brand → not re-suggested', () {
      final out = engine.generate(
        detectedServices: [
          svc('Amazon', OtpCategory.ecommerce, 12),
          svc('Swiggy', OtpCategory.foodDelivery, 5),
        ],
        existingRules: const [
          ForwardRule(id: 'rule-1', name: 'Amazon rule', brands: ['amazon']),
        ],
        recipients: recipients,
        clock: fixedClock,
      );
      expect(out, hasLength(1));
      expect(out.single.proposedRule.brands, ['Swiggy']);
    });

    test('enabled rule covering the category → not re-suggested', () {
      final out = engine.generate(
        detectedServices: [
          svc('Amazon', OtpCategory.ecommerce, 12),
          svc('Swiggy', OtpCategory.foodDelivery, 5),
        ],
        existingRules: const [
          ForwardRule(
            id: 'rule-1',
            name: 'All food',
            categories: {OtpCategory.foodDelivery},
          ),
        ],
        recipients: recipients,
        clock: fixedClock,
      );
      expect(out, hasLength(1));
      expect(out.single.proposedRule.brands, ['Amazon']);
    });

    test('a DISABLED rule does not suppress a suggestion', () {
      final out = engine.generate(
        detectedServices: [svc('Amazon', OtpCategory.ecommerce, 12)],
        existingRules: const [
          ForwardRule(
            id: 'rule-1',
            name: 'Amazon rule',
            brands: ['Amazon'],
            enabled: false,
          ),
        ],
        recipients: recipients,
        clock: fixedClock,
      );
      expect(out, hasLength(1));
      expect(out.single.proposedRule.brands, ['Amazon']);
    });

    test('high-risk categories propose approval/block, never plain forward',
        () {
      final out = engine.generate(
        detectedServices: [
          svc('HDFC Bank', OtpCategory.bankingTransaction, 20),
          svc('Zerodha', OtpCategory.investment, 8),
        ],
        existingRules: const [],
        recipients: recipients,
        clock: fixedClock,
      );

      expect(out, hasLength(2));
      for (final suggestion in out) {
        expect(suggestion.proposedRule.action, isNot(RuleAction.forward));
        expect(
          suggestion.proposedRule.action,
          anyOf(RuleAction.block, RuleAction.requireApproval),
        );
        // The body must say why we are not auto-forwarding.
        expect(suggestion.body.toLowerCase(), contains('approval'));
      }
    });

    test('respects max, keeping the most-messaged services', () {
      final out = engine.generate(
        detectedServices: [
          svc('Uber', OtpCategory.rideBooking, 1),
          svc('Amazon', OtpCategory.ecommerce, 30),
          svc('Netflix', OtpCategory.entertainment, 2),
          svc('Swiggy', OtpCategory.foodDelivery, 25),
          svc('Zepto', OtpCategory.grocery, 9),
          svc('OYO', OtpCategory.hotel, 4),
        ],
        existingRules: const [],
        recipients: recipients,
        clock: fixedClock,
        max: 3,
      );
      expect(out, hasLength(3));
      expect(
        out.map((s) => s.proposedRule.brands.single).toList(),
        ['Amazon', 'Swiggy', 'Zepto'],
      );
    });

    test('default cap is 4', () {
      final out = engine.generate(
        detectedServices: List.generate(
          7,
          (i) => svc('Brand$i', OtpCategory.ecommerce, 10 + i),
        ),
        existingRules: const [],
        recipients: recipients,
        clock: fixedClock,
      );
      expect(out, hasLength(4));
    });

    test('no recipients → recipientIds left empty for the UI to fill', () {
      final out = engine.generate(
        detectedServices: [svc('Amazon', OtpCategory.ecommerce, 12)],
        existingRules: const [],
        recipients: const [],
        clock: fixedClock,
      );
      expect(out.single.proposedRule.recipientIds, isEmpty);
    });

    test('duplicate brands collapse into a single suggestion', () {
      final out = engine.generate(
        detectedServices: [
          svc('Airtel', OtpCategory.telecom, 6),
          svc('Airtel', OtpCategory.recharge, 3),
        ],
        existingRules: const [],
        recipients: recipients,
        clock: fixedClock,
      );
      expect(out, hasLength(1));
      expect(out.single.proposedRule.brands, ['Airtel']);
    });

    test('services with zero messages are ignored', () {
      final out = engine.generate(
        detectedServices: [svc('Amazon', OtpCategory.ecommerce, 0)],
        existingRules: const [],
        recipients: recipients,
        clock: fixedClock,
      );
      expect(out, isEmpty);
    });
  });
}
