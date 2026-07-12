# OTPBridge — Integration Brief (read before writing any code)

You are building part of **OTPBridge**, a premium, minimalist Flutter app for
intelligent, rule-based OTP forwarding. Aesthetic: Linear / Notion / Monzo /
Stripe. Trust-first, lots of whitespace, subtle motion, no flashy colors.

Flutter 3.29 · Dart 3.7 · Material 3 · Riverpod · GoRouter. Null-safe. No
`flutter_gen`/codegen. Do **not** run `flutter pub add`; all deps are pinned in
pubspec.yaml already (flutter_riverpod, go_router, hive, hive_flutter,
flutter_secure_storage, local_auth, permission_handler,
flutter_local_notifications, dio, intl, uuid, collection, equatable).

## Golden rules
- **Never edit files outside your assigned list.** Other agents own the rest.
- Use design tokens, never raw hex. Access via `context.tokens` (see below).
- Use `ConsumerWidget` / `ConsumerStatefulWidget` from flutter_riverpod.
- Every tappable ≥ 48dp. Respect safe areas. Support light + dark.
- SVG/`IconData` only — never emoji as icons.
- Keep it calm: max 1–2 animated elements per view, 150–320ms, ease-out.

## Design tokens — `lib/core/theme/`
`import 'package:otpbridge/core/theme/app_colors.dart';` then `context.tokens`:
`.background .surface .surfaceRaised .surfaceSunken .glassFill .glassBorder
.border .borderStrong .textPrimary .textSecondary .textTertiary .primary
.onPrimary .primarySubtle .onPrimarySubtle .success .successSubtle .warning
.warningSubtle .danger .dangerSubtle .info .infoSubtle .shadow`

`AppSpacing` (app_spacing.dart): xxs=4 xs=8 sm=12 md=16 lg=20 xl=24 xxl=32
xxxl=40 huge=48 massive=64; `screenH=20` (horizontal screen padding);
`touchTarget=48`.
`AppRadius`: sm=10 md=14 lg=20 xl=28 pill=999.
`AppMotion`: fast=150ms base=220ms slow=320ms; curves enter/exit/emphasized.

Typography via `Theme.of(context).textTheme` (displayLarge…labelSmall, Inter).
For OTP codes / amounts use `MonoText.otp(context)` / `MonoText.amount(context)`
from `app_theme.dart` (JetBrains Mono, tabular figures).

## Shared widgets — `lib/core/widgets/widgets.dart`
- `GlassCard({child, padding, onTap, frosted, raised, borderColor, radius})`
- `StatusPill({label, tone: PillTone.{neutral,primary,success,warning,danger,info}, icon, dense})`
- `SectionHeader({title, subtitle, trailing, padding})`
- `CategoryAvatar({category, size})` — takes an `OtpCategory`
- `EmptyState({icon, title, message, action})`

## Models — `lib/domain/models/models.dart` (single barrel import)
`OtpCategory` (enum with `.label .icon .risk .isFinancial`, `RiskTier`),
`IncomingSms`, `SmsClassification` (`.otp .brand .amount .category .confidence
.merchant .transactionType .hasOtp`), `Recipient` (`.initials .preferredChannel`)
+ `RecipientGroup` + `ForwardChannel` (`.label`), `ForwardRule` (+ `RuleSchedule`,
`ScheduleKind`, `RuleAction`), `ForwardTask` (+ `ForwardStatus`), `HistoryEntry`
(+ `OtpOutcome` with `.label`), `PendingApproval`, `AppSettings`,
`SubscriptionState` (+ `SubscriptionTier`, `TierLimits`), `AiSuggestion`,
`RuleDecision` (+ `DecisionKind`). All are immutable with `copyWith`/`toJson`/
`fromJson`. Read the files for exact fields.

## Providers — `lib/app/providers.dart`
StreamProviders (use `ref.watch(x).when(...)` or `.valueOrNull`):
`settingsProvider`→AppSettings, `subscriptionProvider`→SubscriptionState,
`rulesProvider`→List<ForwardRule>, `recipientsProvider`→List<Recipient>,
`historyProvider`→List<HistoryEntry>, `queueProvider`→List<ForwardTask>,
`approvalsProvider`→List<PendingApproval>, `suggestionsProvider`→List<AiSuggestion>.

Repos (for writes) — `ref.read(xRepositoryProvider)`:
`rulesRepositoryProvider .save/.saveAll/.remove/.getAll`,
`recipientsRepositoryProvider .save/.remove/.getAll/.getGroups/.saveGroup`,
`settingsRepositoryProvider .save/.get`,
`subscriptionRepositoryProvider .save/.get`,
`historyRepositoryProvider .clear`,
`suggestionsRepositoryProvider .save/.remove`.
Pipeline (for approve/reject): `ref.read(smsPipelineProvider).approve(x)/.reject(x)`.
SMS gateway: `ref.read(smsGatewayProvider)` — `.capabilities() .hasPermissions()
.requestPermissions() .startListening() .isListening()`.

## Routes — `lib/app/router.dart` (`Routes.*`)
`onboarding dashboard rules history settings ruleEditor recipients
recipientEditor paywall`. Navigate with `context.push(Routes.x)` /
`context.go(Routes.x)`. RuleEditor & RecipientEditor take the entity via
`extra:` (null = create). Use `import 'package:go_router/go_router.dart';`.

## Package import prefix
This package is `otpbridge`. Import shared code as
`package:otpbridge/...`. Example:
`import 'package:otpbridge/core/widgets/widgets.dart';`

## Quality bar
Your code must pass `flutter analyze` with zero errors. Prefer `const`
constructors. No `print`. No unused imports. Keep each screen in its own file.
