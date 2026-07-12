import 'package:flutter_test/flutter_test.dart';
import 'package:otpbridge/data/classification/classification_engine_impl.dart';
import 'package:otpbridge/data/rules/nl_rule_parser.dart';
import 'package:otpbridge/domain/models/forward_rule.dart';
import 'package:otpbridge/domain/models/recipient.dart';

void main() {
  final parser = NaturalLanguageRuleParser(DefaultClassificationEngine());

  const rahul = Recipient(id: 'r1', name: 'Rahul Sharma', phone: '+911');
  const ramesh = Recipient(id: 'r2', name: 'Ramesh CA', phone: '+912');
  final recipients = [rahul, ramesh];

  test('forwards a brand to a named recipient', () {
    final d = parser.parse('Forward all Amazon orders to Rahul',
        recipients: recipients);
    expect(d.brands.map((b) => b.toLowerCase()), contains('amazon'));
    expect(d.action, RuleAction.forward);
    expect(d.recipientIds, contains('r1'));
    expect(d.missing, isNot(contains('recipient')));
    expect(d.confidence, greaterThan(0.7));
  });

  test('block intent needs no recipient', () {
    final d = parser.parse('Block all banking messages', recipients: recipients);
    expect(d.action, RuleAction.block);
    expect(d.missing, isNot(contains('recipient')));
  });

  test('detects office-hours schedule', () {
    final d = parser.parse('Send Amazon updates to Rahul during office hours',
        recipients: recipients);
    expect(d.schedule.kind, ScheduleKind.workingHours);
  });

  test('detects weekend schedule', () {
    final d = parser.parse('forward swiggy to Rahul on weekends',
        recipients: recipients);
    expect(d.schedule.kind, ScheduleKind.weekends);
  });

  test('matches recipient by first name', () {
    final d = parser.parse('send all bank otps to Ramesh every month',
        recipients: recipients);
    expect(d.recipientIds, contains('r2'));
    expect(d.categories.any((c) => c.isFinancial), isTrue);
  });

  test('flags missing recipient when none named', () {
    final d = parser.parse('forward grocery messages', recipients: recipients);
    expect(d.missing, contains('recipient'));
  });

  test('produces a usable ForwardRule', () {
    final d =
        parser.parse('forward Amazon to Rahul', recipients: recipients);
    final rule = d.toRule(id: 'x', sortOrder: 3, now: DateTime(2026));
    expect(rule.id, 'x');
    expect(rule.sortOrder, 3);
    expect(rule.recipientIds, contains('r1'));
  });
}
