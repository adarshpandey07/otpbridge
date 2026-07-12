# OTPBridge — Architecture

## Principles

- **Clean Architecture, feature-first.** Domain is pure Dart with zero Flutter
  or plugin imports. Data implements domain contracts. Features (UI) depend on
  domain + core, never on data internals directly (only via providers).
- **Offline-first.** Everything works with no network. The backend is an
  optional mirror, not a dependency.
- **Backend-swappable.** No repository or feature references Supabase/Firebase
  directly. A `RemoteSyncService` (future) mirrors local stores; swapping
  providers touches one module.
- **Platform-abstracted.** Android capabilities (SMS read/send, foreground
  service) sit behind `SmsGateway`. iOS/desktop/tests use `CompanionSmsGateway`.
  `PlatformCapabilities` lets the UI degrade gracefully.

## Layers

```
┌─────────────────────────────────────────────────────────────┐
│ features/  (Flutter UI, ConsumerWidgets)                    │
│   onboarding · dashboard · rules · recipients · history ·   │
│   settings · approvals · paywall · shell                    │
└───────────────▲─────────────────────────────────────────────┘
                │ Riverpod providers (app/providers.dart)
┌───────────────┴─────────────────────────────────────────────┐
│ domain/  (pure)                                             │
│   models/         immutable entities + JSON                 │
│   repositories/   abstract contracts                        │
│   services/       ClassificationEngine, RuleEngine,         │
│                   ForwardingQueue, SmsGateway,              │
│                   NotificationService, SmsPipeline (glue)   │
└───────────────▲─────────────────────────────────────────────┘
                │ implemented by
┌───────────────┴─────────────────────────────────────────────┐
│ data/                                                       │
│   repositories/   Hive (AES-encrypted) implementations      │
│   classification/ hybrid classifier + brand catalog         │
│   rules/          rule engine + schedule evaluator          │
│   queue/          persistent offline forwarding queue       │
│   platform/       Android SMS gateway + local notifications │
│   seed/           sample data loader                        │
└───────────────▲─────────────────────────────────────────────┘
                │
┌───────────────┴─────────────────────────────────────────────┐
│ core/                                                       │
│   theme/    design tokens (AppTokens ThemeExtension),       │
│             AppSpacing/AppRadius/AppMotion, AppTheme         │
│   widgets/  GlassCard, StatusPill, SectionHeader,           │
│             CategoryAvatar, EmptyState                       │
│   storage/  LocalStore (Hive + keystore-held AES key)       │
└─────────────────────────────────────────────────────────────┘
```

## The pipeline (`domain/services/sms_pipeline.dart`)

`SmsPipeline.process(IncomingSms)` is the single entry point invoked for each
message (from the Android gateway stream, or manually in tests):

1. **Gate** — bail if `settings.listeningEnabled` is false.
2. **Classify** — `ClassificationEngine.classify` → `SmsClassification`. Non-OTP
   messages are ignored (no history noise).
3. **Dedupe** — `IncomingSms.fingerprint` (sender+body+minute-bucket, SHA-256)
   checked against a rolling set for replay protection.
4. **Rule match** — `RuleEngine.evaluate` returns a `RuleDecision`
   (forward / block / requireApproval / noMatch), honoring schedules, amount
   caps, the global banking cap, and the high-risk-approval setting.
5. **Branch:**
   - *block* → record + notify.
   - *requireApproval* → create a `PendingApproval` (TTL), notify.
   - *forward* → subscription gate → resolve recipients → enqueue.
6. **Enqueue** — `ForwardingQueue.enqueueForDecision` creates one `ForwardTask`
   per recipient; `processDue()` attempts immediate delivery. The background
   timer retries with exponential backoff.
7. **Record** — a `HistoryEntry` is written for every outcome; notifications
   fire per lifecycle event.

## State management

Riverpod. Repositories expose `Stream`s (`watch()`), surfaced as
`StreamProvider`s (`rulesProvider`, `historyProvider`, …). UI reads with
`.when`/`.valueOrNull`; writes go through repo providers or the pipeline.
DI is centralized in `app/providers.dart`; `localStoreProvider`,
`smsGatewayProvider`, and `notificationServiceProvider` are overridden at
bootstrap (real impls in `main`, fakes in tests).

## Extension points

| Want to add… | Do this | No change to… |
|--------------|---------|---------------|
| A new delivery channel (WhatsApp/Telegram/Email) | implement `ForwardChannelPlugin`, register in `ChannelRegistry` | pipeline, rules, queue, UI |
| A better classifier (ONNX/TFLite/cloud) | implement `ClassificationEngine`, swap the provider | everything else |
| A new SMS-capture strategy (notification listener / default handler) | implement `SmsGateway`, override the provider | pipeline, UI |
| A cloud backend | add `RemoteSyncService` mirroring repos | domain, features |
| A new screen | add under `features/`, register a route | other features |

## Security model

- **At rest:** all Hive boxes opened with `HiveAesCipher`; the 256-bit key is
  generated once and stored in the platform keystore via
  `flutter_secure_storage` (never in the box itself).
- **In app:** optional app-lock / biometric gate; OTP masking in notifications;
  high-risk manual approval; duplicate/replay protection.
- **Data minimization:** OTP contents never need to leave the device to be
  classified. If cloud sync is enabled later, sync rules/recipients/redacted
  history only — never raw OTP bodies.

## Background execution

- Android foreground service (`SmsListenerService`) keeps the SMS receiver
  alive; an ongoing notification is shown (OS requirement + transparency).
- The forwarding queue also runs an in-process `Timer.periodic`. For delivery
  that must survive app-death, wire `workmanager` to call
  `ForwardingQueue.processDue()` (hook documented in the queue impl).
