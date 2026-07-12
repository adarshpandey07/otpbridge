# OTPBridge — Phase 2 Brief (product refinement)

Read `INTEGRATION_BRIEF.md` first for the design system (tokens, shared widgets,
`context.tokens`, `AppSpacing`, `AppRadius`, textTheme, `GlassCard`,
`StatusPill`, `SectionHeader`, `CategoryAvatar`, `EmptyState`). This doc lists
the NEW APIs added for phase 2. Package prefix: `package:otpbridge/...`.

Goal of phase 2: **remove manual typing, make it feel like a smart assistant,
and make every feature actually work.** Optimize for less user effort.

## New models (`package:otpbridge/domain/models/models.dart`)
- `OtpCategory` now also has: `recharge, insurance, tax, investment, promotions`.
  Each `OtpCategory` has `.group` → a `CategoryGroup`.
- `CategoryGroup` — high-level buckets for the wizard's first step. Values:
  `shopping, grocery, food, banking, finance, bills, travel, health,
  government, accounts, entertainment, promotions, other`. Each has
  `.label`, `.icon`, `.categories` (the detailed `OtpCategory` set it maps to).
- `DetectedService { brand, category, sampleSender, messageCount, lastSeen }`
  with `.group`. Represents a brand/app the user actually gets SMS from.

## New services & providers (`package:otpbridge/app/providers.dart`)
- `detectedServicesProvider` → `FutureProvider<List<DetectedService>>` — scans
  the SMS inbox and returns detected services, most-messaged first. Empty on
  iOS/no-permission. USE THIS for "dynamic service detection".
- `serviceDetectorProvider` → `ServiceDetector` with
  `detectAll({scan})` and `detectForGroup(CategoryGroup, {scan})`.
- `nlRuleParserProvider` → `NaturalLanguageRuleParser` with
  `RuleDraft parse(String text, {required List<Recipient> recipients})`.
  `RuleDraft` has `.suggestedName .categories .brands .recipientIds .schedule
  .action .confidence .explanation .missing` (list of unfilled slots like
  `'recipient'`, `'what'`) and `.toRule({required id, sortOrder, now})`.
- `contactsServiceProvider` → `ContactsService`:
  `isSupported() hasPermission() requestPermission() getAll() pickOne()`.
  Returns `DeviceContact { id, name, phones, emails, primaryPhone,
  primaryEmail, initials }`.
- `billingServiceProvider` → `BillingService`:
  `isConfigured` (bool), `checkout({required PremiumPlan plan, required String
  userName, String? email, String? phone})` → `Future<BillingResult>` with
  `.isSuccess .status .paymentId .signature .message`. `PremiumPlan.monthly`
  (₹99) / `PremiumPlan.yearly`. In DEMO mode (no key) checkout auto-succeeds
  after ~1s so the flow is testable; real Razorpay opens when a key is set.
- App-lock: `appLockControllerProvider` (StateNotifierProvider) exposes
  `AppLockState { phase, enabled, biometricEnabled, checking, error, isGating }`
  and the notifier has `applySettings(AppSettings)`, `onPaused()`, `onResumed()`,
  `lockNow()`, `unlockWithBiometric()`, `unlockWithPin(String)`, `hasPin()`.
  `pinStoreProvider` → `PinStore { hasPin(), setPin(pin), verify(pin), clear() }`.
  `biometricAuthProvider` → `BiometricAuth { isAvailable(), authenticate() }`.
  The lock GATE + LockScreen are already built and wired in `app.dart`.

## New settings fields (`AppSettings`)
- `appLockAfterMinutes` (int; 0 = immediate). Plus existing `appLockEnabled`,
  `biometricEnabled`.

## Repos for writes (existing)
`ref.read(rulesRepositoryProvider).save/.saveAll/.remove`,
`recipientsRepositoryProvider.save/.remove/.getAll`,
`settingsRepositoryProvider.save/.get`,
`subscriptionRepositoryProvider.save/.get`,
`suggestionsRepositoryProvider.save/.remove`.
Streams: `rulesProvider recipientsProvider historyProvider settingsProvider
subscriptionProvider suggestionsProvider approvalsProvider queueProvider`.

## Routes (`Routes.*` in `package:otpbridge/app/router.dart`)
Existing: `dashboard rules history settings ruleEditor recipients
recipientEditor paywall onboarding`. If you add a screen that needs a route,
tell the integrator (do NOT edit router.dart unless told to own it) — prefer
pushing a `MaterialPageRoute`/showModalBottomSheet from within your feature, or
note the route you need.

## Rules for all agents
- NO raw hex — use `context.tokens`. `Icons.*` only, no emoji. Tap targets ≥48dp.
- ConsumerWidget/ConsumerStatefulWidget. Streams via `.when`/`.valueOrNull`.
- Only edit files in YOUR assigned list. Do NOT run `flutter pub get` or edit
  pubspec/providers/router/app.dart/main.dart unless your task says you own it.
- Must pass `flutter analyze` on your files (0 errors). Prefer `const`.
- When a screen would otherwise ask the user to TYPE something the app can
  infer (brand, sender, category, recipient name/phone), infer it instead.
