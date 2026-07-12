import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/app_lock_controller.dart';
import '../core/security/biometric_auth.dart';
import '../core/security/pin_store.dart';
import '../core/storage/local_store.dart';
import '../data/classification/classification_engine_impl.dart';
import '../data/classification/service_detector.dart';
import '../data/queue/forwarding_queue_impl.dart';
import '../data/repositories/hive_repositories.dart';
import '../data/rules/nl_rule_parser.dart';
import '../data/rules/rule_engine_impl.dart';
import '../data/seed/sample_data.dart';
import '../domain/models/models.dart';
import '../domain/repositories/repositories.dart';
import '../domain/services/billing_service.dart';
import '../domain/services/contacts_service.dart';
import '../domain/services/forward_channel_plugin.dart';
import '../domain/services/notification_service.dart';
import '../domain/services/service_contracts.dart';
import '../domain/services/sms_gateway.dart';
import '../domain/services/sms_pipeline.dart';

/// ── Infrastructure (overridden at bootstrap) ──────────────────────────────

/// Provides the opened, encrypted [LocalStore]. Overridden in main() after
/// async open; overridden with an in-memory store in tests.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('localStoreProvider must be overridden'),
);

/// The native SMS gateway. Overridden with the Android impl on Android, the
/// companion impl on iOS/desktop/tests.
final smsGatewayProvider = Provider<SmsGateway>((ref) => CompanionSmsGateway());

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NoopNotificationService());

/// Device contacts. Overridden with the real impl on Android/iOS in main().
final contactsServiceProvider =
    Provider<ContactsService>((ref) => NoopContactsService());

/// Payment gateway. Overridden with Razorpay in main(); Noop elsewhere/tests.
final billingServiceProvider = Provider<BillingService>((ref) {
  final service = NoopBillingService();
  ref.onDispose(service.dispose);
  return service;
});

/// ── Repositories ──────────────────────────────────────────────────────────

final rulesRepositoryProvider = Provider<RulesRepository>(
    (ref) => HiveRulesRepository(ref.watch(localStoreProvider)));

final recipientsRepositoryProvider = Provider<RecipientsRepository>(
    (ref) => HiveRecipientsRepository(ref.watch(localStoreProvider)));

final historyRepositoryProvider = Provider<HistoryRepository>(
    (ref) => HiveHistoryRepository(ref.watch(localStoreProvider)));

final queueRepositoryProvider = Provider<QueueRepository>(
    (ref) => HiveQueueRepository(ref.watch(localStoreProvider)));

final approvalsRepositoryProvider = Provider<ApprovalsRepository>(
    (ref) => HiveApprovalsRepository(ref.watch(localStoreProvider)));

final settingsRepositoryProvider = Provider<SettingsRepository>(
    (ref) => HiveSettingsRepository(ref.watch(localStoreProvider)));

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
    (ref) => HiveSubscriptionRepository(ref.watch(localStoreProvider)));

final suggestionsRepositoryProvider = Provider<SuggestionsRepository>(
    (ref) => HiveSuggestionsRepository(ref.watch(localStoreProvider)));

/// ── Engines & services ────────────────────────────────────────────────────

final classificationEngineProvider =
    Provider<ClassificationEngine>((ref) => DefaultClassificationEngine());

final ruleEngineProvider = Provider<RuleEngine>((ref) => DefaultRuleEngine());

/// Scans the SMS inbox to detect which brands/apps actually message the user.
final serviceDetectorProvider = Provider<ServiceDetector>((ref) =>
    ServiceDetector(ref.watch(smsGatewayProvider),
        ref.watch(classificationEngineProvider)));

/// One-shot detection of services from the inbox (used by the rule wizard).
final detectedServicesProvider =
    FutureProvider<List<DetectedService>>((ref) async {
  return ref.watch(serviceDetectorProvider).detectAll();
});

/// Parses natural-language sentences into draft rules (offline, on-device).
final nlRuleParserProvider = Provider<NaturalLanguageRuleParser>(
    (ref) => NaturalLanguageRuleParser(ref.watch(classificationEngineProvider)));

/// ── Security / app lock ───────────────────────────────────────────────────

final pinStoreProvider = Provider<PinStore>((ref) => PinStore());
final biometricAuthProvider = Provider<BiometricAuth>((ref) => BiometricAuth());

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(
    pinStore: ref.watch(pinStoreProvider),
    biometric: ref.watch(biometricAuthProvider),
  );
});

final channelRegistryProvider = Provider<ChannelRegistry>((ref) {
  return ChannelRegistry([
    SmsChannelPlugin(ref.watch(smsGatewayProvider)),
  ]);
});

final forwardingQueueProvider = Provider<ForwardingQueue>((ref) {
  return DefaultForwardingQueue(
    queueRepo: ref.watch(queueRepositoryProvider),
    historyRepo: ref.watch(historyRepositoryProvider),
    channels: ref.watch(channelRegistryProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});

final smsPipelineProvider = Provider<SmsPipeline>((ref) {
  return SmsPipeline(
    classifier: ref.watch(classificationEngineProvider),
    ruleEngine: ref.watch(ruleEngineProvider),
    queue: ref.watch(forwardingQueueProvider),
    rulesRepo: ref.watch(rulesRepositoryProvider),
    recipientsRepo: ref.watch(recipientsRepositoryProvider),
    historyRepo: ref.watch(historyRepositoryProvider),
    approvalsRepo: ref.watch(approvalsRepositoryProvider),
    settingsRepo: ref.watch(settingsRepositoryProvider),
    subscriptionRepo: ref.watch(subscriptionRepositoryProvider),
    queueRepo: ref.watch(queueRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});

/// ── Reactive state streams ────────────────────────────────────────────────

final settingsProvider = StreamProvider<AppSettings>(
    (ref) => ref.watch(settingsRepositoryProvider).watch());

final subscriptionProvider = StreamProvider<SubscriptionState>(
    (ref) => ref.watch(subscriptionRepositoryProvider).watch());

final rulesProvider = StreamProvider<List<ForwardRule>>(
    (ref) => ref.watch(rulesRepositoryProvider).watch());

final recipientsProvider = StreamProvider<List<Recipient>>(
    (ref) => ref.watch(recipientsRepositoryProvider).watch());

final historyProvider = StreamProvider<List<HistoryEntry>>(
    (ref) => ref.watch(historyRepositoryProvider).watch());

final queueProvider = StreamProvider<List<ForwardTask>>(
    (ref) => ref.watch(queueRepositoryProvider).watch());

final approvalsProvider = StreamProvider<List<PendingApproval>>(
    (ref) => ref.watch(approvalsRepositoryProvider).watch());

final suggestionsProvider = StreamProvider<List<AiSuggestion>>(
    (ref) => ref.watch(suggestionsRepositoryProvider).watch());

/// ── Dev / demo ────────────────────────────────────────────────────────────

/// Seeds realistic demo rules/recipients/history so the app is explorable
/// without a live SMS feed (emulator, iOS companion, first run).
final sampleDataProvider = Provider<SampleData>((ref) => SampleData(
      rules: ref.watch(rulesRepositoryProvider),
      recipients: ref.watch(recipientsRepositoryProvider),
      history: ref.watch(historyRepositoryProvider),
      suggestions: ref.watch(suggestionsRepositoryProvider),
    ));
