import 'package:uuid/uuid.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';

/// Seeds realistic demo data so the app is explorable and testable without a
/// live SMS feed (e.g. on an emulator or iOS). Idempotent-ish: it clears and
/// repopulates the rules/recipients/history stores.
class SampleData {
  const SampleData({
    required this.rules,
    required this.recipients,
    required this.history,
    required this.suggestions,
    this.uuid = const Uuid(),
    this.clock = DateTime.now,
  });

  final RulesRepository rules;
  final RecipientsRepository recipients;
  final HistoryRepository history;
  final SuggestionsRepository suggestions;
  final Uuid uuid;
  final DateTime Function() clock;

  Future<void> load() async {
    final now = clock();

    final rahul = Recipient(
      id: uuid.v4(),
      name: 'Rahul Sharma',
      phone: '+919812345678',
      preferredChannel: ForwardChannel.sms,
      createdAt: now,
    );
    final mom = Recipient(
      id: uuid.v4(),
      name: 'Mummy',
      phone: '+919845612300',
      preferredChannel: ForwardChannel.sms,
      createdAt: now,
    );
    await recipients.save(rahul);
    await recipients.save(mom);

    final amazonRule = ForwardRule(
      id: uuid.v4(),
      name: 'Amazon deliveries → Rahul',
      sortOrder: 0,
      categories: {OtpCategory.ecommerce, OtpCategory.courier},
      brands: const ['Amazon'],
      schedule: const RuleSchedule(
        kind: ScheduleKind.custom,
        days: {1, 2, 3, 4, 5},
        start: null,
        end: null,
      ),
      action: RuleAction.forward,
      recipientIds: [rahul.id],
      timesTriggered: 12,
      createdAt: now,
    );
    final groceryRule = ForwardRule(
      id: uuid.v4(),
      name: 'Groceries → Mummy',
      sortOrder: 1,
      categories: {OtpCategory.grocery},
      action: RuleAction.forward,
      recipientIds: [mom.id],
      timesTriggered: 5,
      createdAt: now,
    );
    final bankRule = ForwardRule(
      id: uuid.v4(),
      name: 'Never forward banking',
      sortOrder: 2,
      categories: {
        OtpCategory.bankingTransaction,
        OtpCategory.creditCard,
        OtpCategory.debitCard,
      },
      action: RuleAction.block,
      createdAt: now,
    );
    await rules.saveAll([amazonRule, groceryRule, bankRule]);

    IncomingSms sms(String sender, String body, Duration ago) => IncomingSms(
          id: uuid.v4(),
          sender: sender,
          body: body,
          receivedAt: now.subtract(ago),
        );

    final samples = <HistoryEntry>[
      HistoryEntry(
        id: uuid.v4(),
        at: now.subtract(const Duration(minutes: 8)),
        classification: SmsClassification(
          sms: sms('VM-AMAZON', 'Your Amazon OTP is 563412', const Duration(minutes: 8)),
          category: OtpCategory.ecommerce,
          confidence: 0.98,
          otp: '563412',
          brand: 'Amazon',
          engine: 'rules',
        ),
        outcome: OtpOutcome.forwarded,
        ruleId: amazonRule.id,
        ruleName: amazonRule.name,
        recipientNames: [rahul.name],
        detail: 'Delivered to Rahul Sharma',
      ),
      HistoryEntry(
        id: uuid.v4(),
        at: now.subtract(const Duration(hours: 2)),
        classification: SmsClassification(
          sms: sms('JD-BLINKIT', 'Blinkit: 4471 is your OTP for order #A12',
              const Duration(hours: 2)),
          category: OtpCategory.grocery,
          confidence: 0.95,
          otp: '4471',
          brand: 'Blinkit',
          engine: 'rules',
        ),
        outcome: OtpOutcome.forwarded,
        ruleId: groceryRule.id,
        ruleName: groceryRule.name,
        recipientNames: [mom.name],
      ),
      HistoryEntry(
        id: uuid.v4(),
        at: now.subtract(const Duration(hours: 5)),
        classification: SmsClassification(
          sms: sms('AX-HDFCBK', 'Rs 8500 debited via UPI. OTP 284761 -HDFC',
              const Duration(hours: 5)),
          category: OtpCategory.bankingTransaction,
          confidence: 0.93,
          otp: '284761',
          brand: 'HDFC',
          amount: 8500,
          transactionType: TransactionType.debit,
          engine: 'rules',
        ),
        outcome: OtpOutcome.blocked,
        ruleId: bankRule.id,
        ruleName: bankRule.name,
        detail: 'Banking OTP — blocked by rule',
      ),
      HistoryEntry(
        id: uuid.v4(),
        at: now.subtract(const Duration(days: 1, hours: 1)),
        classification: SmsClassification(
          sms: sms('VK-SWIGGY', 'Your Swiggy delivery OTP is 8842',
              const Duration(days: 1, hours: 1)),
          category: OtpCategory.foodDelivery,
          confidence: 0.9,
          otp: '8842',
          brand: 'Swiggy',
          engine: 'rules',
        ),
        outcome: OtpOutcome.ignored,
        detail: 'No rule matched',
      ),
    ];
    for (final e in samples) {
      await history.add(e);
    }

    await suggestions.save(AiSuggestion(
      id: uuid.v4(),
      title: 'Automate Amazon OTPs?',
      body: 'You forwarded 4 Amazon OTPs to Rahul this week. Create a rule to '
          'do it automatically during the day.',
      proposedRule: amazonRule.copyWith(name: 'Amazon → Rahul (suggested)'),
      createdAt: now,
    ));
  }
}
