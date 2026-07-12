import 'package:flutter_test/flutter_test.dart';
import 'package:otpbridge/data/queue/forwarding_queue_impl.dart';
import 'package:otpbridge/data/rules/rule_engine_impl.dart';
import 'package:otpbridge/domain/models/models.dart';
import 'package:otpbridge/domain/services/forward_channel_plugin.dart';
import 'package:otpbridge/domain/services/notification_service.dart';
import 'package:otpbridge/domain/services/sms_gateway.dart';
import 'package:otpbridge/domain/services/sms_pipeline.dart';

import '../support/fakes.dart';

/// A channel plugin that always succeeds and records what it "sent".
class FakeChannelPlugin implements ForwardChannelPlugin {
  final List<ForwardTask> delivered = [];
  bool available = true;
  @override
  ForwardChannel get channel => ForwardChannel.sms;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<SmsSendResult> deliver(ForwardTask task) async {
    delivered.add(task);
    return const SmsSendResult.ok();
  }
}

void main() {
  late InMemoryRulesRepository rules;
  late InMemoryRecipientsRepository recipients;
  late InMemoryHistoryRepository history;
  late InMemoryQueueRepository queueRepo;
  late InMemoryApprovalsRepository approvals;
  late InMemorySettingsRepository settings;
  late InMemorySubscriptionRepository subscription;
  late FakeChannelPlugin channel;
  late SmsPipeline pipeline;

  final now = DateTime(2026, 7, 12, 12); // a Sunday noon

  SmsClassification classifierFor(IncomingSms sms) {
    // Simple deterministic stub keyed by content.
    if (sms.body.contains('Amazon')) {
      return SmsClassification(
        sms: sms,
        category: OtpCategory.ecommerce,
        confidence: 0.98,
        otp: '563412',
        brand: 'Amazon',
      );
    }
    if (sms.body.contains('debited')) {
      return SmsClassification(
        sms: sms,
        category: OtpCategory.bankingTransaction,
        confidence: 0.95,
        otp: '284761',
        brand: 'HDFC',
        amount: 8500,
        transactionType: TransactionType.debit,
      );
    }
    if (sms.body.contains('promo')) {
      return SmsClassification(
        sms: sms,
        category: OtpCategory.unknown,
        confidence: 0.2,
      ); // no OTP
    }
    return SmsClassification(
      sms: sms,
      category: OtpCategory.grocery,
      confidence: 0.9,
      otp: '4471',
      brand: 'Blinkit',
    );
  }

  Recipient rahul() => const Recipient(
        id: 'r1',
        name: 'Rahul',
        phone: '+919812345678',
      );

  IncomingSms sms(String body) => IncomingSms(
        id: 'm-$body'.substring(0, 8),
        sender: 'VM-TEST',
        body: body,
        receivedAt: now,
      );

  setUp(() {
    rules = InMemoryRulesRepository();
    recipients = InMemoryRecipientsRepository();
    history = InMemoryHistoryRepository();
    queueRepo = InMemoryQueueRepository();
    approvals = InMemoryApprovalsRepository();
    settings = InMemorySettingsRepository(
        const AppSettings(listeningEnabled: true, highRiskRequiresApproval: true));
    subscription = InMemorySubscriptionRepository();
    channel = FakeChannelPlugin();

    final queue = DefaultForwardingQueue(
      queueRepo: queueRepo,
      historyRepo: history,
      channels: ChannelRegistry([channel]),
      notifications: NoopNotificationService(),
      clock: () => now,
    );

    pipeline = SmsPipeline(
      classifier: StubClassificationEngine(classifierFor),
      ruleEngine: DefaultRuleEngine(),
      queue: queue,
      rulesRepo: rules,
      recipientsRepo: recipients,
      historyRepo: history,
      approvalsRepo: approvals,
      settingsRepo: settings,
      subscriptionRepo: subscription,
      queueRepo: queueRepo,
      notifications: NoopNotificationService(),
      clock: () => now,
    );
  });

  test('forwards Amazon OTP to the configured recipient', () async {
    await recipients.save(rahul());
    await rules.save(ForwardRule(
      id: 'rule1',
      name: 'Amazon → Rahul',
      categories: {OtpCategory.ecommerce},
      recipientIds: const ['r1'],
      createdAt: now,
    ));

    final entry = await pipeline.process(sms('Your Amazon OTP is 563412'));

    expect(entry, isNotNull);
    expect(entry!.outcome, OtpOutcome.queued);
    expect(channel.delivered, hasLength(1));
    expect(channel.delivered.first.destination, '+919812345678');
    expect(history.entries.any((e) => e.outcome == OtpOutcome.forwarded), isTrue);
  });

  test('ignores a non-OTP promotional message', () async {
    final entry = await pipeline.process(sms('Big promo sale today'));
    expect(entry, isNull);
    expect(channel.delivered, isEmpty);
  });

  test('blocks when a block rule matches', () async {
    await rules.save(ForwardRule(
      id: 'block1',
      name: 'Block banking',
      categories: {OtpCategory.bankingTransaction},
      action: RuleAction.block,
      createdAt: now,
    ));
    final entry =
        await pipeline.process(sms('Rs 8500 debited from A/c XX21'));
    expect(entry!.outcome, OtpOutcome.blocked);
    expect(channel.delivered, isEmpty);
  });

  test('escalates high-value banking OTP to approval', () async {
    await recipients.save(rahul());
    // A broad "any category" forward rule; banking is high-risk → approval.
    await rules.save(ForwardRule(
      id: 'any',
      name: 'Forward everything',
      recipientIds: const ['r1'],
      createdAt: now,
    ));
    final entry =
        await pipeline.process(sms('Rs 8500 debited from A/c XX21'));
    expect(entry!.outcome, OtpOutcome.pendingApproval);
    expect(await approvals.getAll(), hasLength(1));
    expect(channel.delivered, isEmpty);
  });

  test('dedupes a duplicate message', () async {
    await recipients.save(rahul());
    await rules.save(ForwardRule(
      id: 'rule1',
      name: 'Amazon → Rahul',
      categories: {OtpCategory.ecommerce},
      recipientIds: const ['r1'],
      createdAt: now,
    ));
    final first = await pipeline.process(sms('Your Amazon OTP is 563412'));
    final second = await pipeline.process(sms('Your Amazon OTP is 563412'));
    expect(first!.outcome, OtpOutcome.queued);
    expect(second!.outcome, OtpOutcome.ignored);
    expect(channel.delivered, hasLength(1)); // only once
  });

  test('approving a pending approval enqueues and delivers', () async {
    await recipients.save(rahul());
    await rules.save(ForwardRule(
      id: 'any',
      name: 'Forward everything',
      recipientIds: const ['r1'],
      createdAt: now,
    ));
    await pipeline.process(sms('Rs 8500 debited from A/c XX21'));
    final approval = (await approvals.getAll()).single;

    await pipeline.approve(approval);

    expect(await approvals.getAll(), isEmpty);
    expect(channel.delivered, hasLength(1));
    expect(history.entries.any((e) => e.outcome == OtpOutcome.approved), isTrue);
  });
}
