# OTPBridge

![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-informational)
![Flutter](https://img.shields.io/badge/Flutter-3.29-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.7-0175C2?logo=dart)
![Tests](https://img.shields.io/badge/tests-165%20passing-success)
![Architecture](https://img.shields.io/badge/architecture-Clean%20%2B%20Riverpod-4F46E5)
![License](https://img.shields.io/badge/license-Proprietary-lightgrey)

**Intelligent, rule-based, secure OTP forwarding.**

Instead of "forward every SMS," OTPBridge forwards *only the OTPs you choose* to
*exactly the right person* — e.g. *"Forward Amazon OTPs to Rahul, 10 AM–7 PM"* or
*"Forward grocery OTPs to Mummy, but never banking OTPs."*

Built with Flutter (Material 3), Clean Architecture, Riverpod, GoRouter, and an
offline-first, on-device AI classification pipeline.

> ⚠️ **Read [`docs/FEASIBILITY.md`](docs/FEASIBILITY.md) first.** Automatic
> SMS reading is Android-only and is restricted on the public Play Store. This
> build ships as a fully-functional **direct-APK / internal-testing** app;
> public-store distribution requires the policy strategy described there.

---

## Features

- **On-device AI classification** — hybrid rules + regex + 60-brand catalog.
  Extracts OTP, brand, amount, merchant, transaction type, category, and a
  confidence score. Works fully offline. 23 categories with risk tiers.
- **Rule engine** — priority-ordered rules matching category / brand / sender /
  keyword, with time & date schedules, per-rule amount caps, and security
  escalation (banking cap, high-risk manual approval).
- **Offline queue** — persistent, exponential backoff, duplicate protection,
  delivery-state tracking. Survives no-network / flight mode / reboot.
- **Manual approval** for high-risk OTPs, with a live countdown.
- **Pluggable channels** — SMS ships in v1; WhatsApp / Telegram / Email / Push
  slot in via `ForwardChannelPlugin` with no pipeline changes.
- **Security** — AES-encrypted local storage (Hive + keystore key), app lock /
  biometric, OTP masking, replay protection.
- **Subscription** — free tier (50 forwards/mo, 1 recipient, 3 rules) vs
  premium (₹99/mo, unlimited + advanced controls).
- **Polished UI** — Linear/Monzo-grade design system, light + dark, dashboard
  with stats, searchable history timeline, onboarding, settings.

## Architecture

Feature-first Clean Architecture. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

```
lib/
├── app/            # App root, DI (Riverpod providers), router
├── core/           # Design system (theme/tokens), shared widgets, storage
├── domain/         # Models, repository contracts, service contracts (pure)
├── data/           # Repo impls (Hive), engines (classify/rules/queue),
│                   # platform (Android SMS, notifications), seed data
└── features/       # UI: onboarding, dashboard, rules, recipients, history,
                    # settings, approvals, paywall, shell
```

The flow for each incoming SMS:

```
SMS → classify → rule match → security validation → recipient resolution
    → offline-queue enqueue → forward → history → notify
```

…orchestrated by `SmsPipeline` (`lib/domain/services/sms_pipeline.dart`).

## Getting started

```bash
flutter pub get
flutter run              # emulator or device
flutter test             # unit tests (classification, rules, queue)
flutter analyze          # static analysis
flutter build apk --release
```

On a non-Android platform (or emulator without SMS), the app runs in
**companion mode** — configure rules/recipients, browse history, but no
auto-reading. Use the in-app **"Load sample data"** action (Settings ▸ Data) to
populate demo rules, recipients, and history for exploring the UI.

## Documentation

| Doc | Contents |
|-----|----------|
| [`docs/FEASIBILITY.md`](docs/FEASIBILITY.md) | Play policy, iOS limits, trust — **read this** |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Layers, data flow, extension points |
| [`docs/BACKEND.md`](docs/BACKEND.md) | Supabase schema, API contracts, sync design |
| [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) | Signing, build, release, CI/CD |
| [`docs/PLAY_STORE_CHECKLIST.md`](docs/PLAY_STORE_CHECKLIST.md) | Store-readiness checklist |
| [`docs/TESTING.md`](docs/TESTING.md) | Test strategy & coverage |
| [`INTEGRATION_BRIEF.md`](INTEGRATION_BRIEF.md) | Design-system + provider API reference |

## License

Proprietary — all rights reserved (placeholder; set your license before release).
