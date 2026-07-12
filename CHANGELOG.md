# Changelog

## 1.1.0 — Product refinement (automation, less friction, real features)

Focus: remove manual typing, make the app intelligent, and make every
advertised feature actually work. Audited the whole codebase first, then
completed/fixed rather than duplicated.

### Added
- **Dynamic service detection** — reads the SMS inbox (`content://sms/inbox`),
  classifies it, and surfaces only the brands/apps that actually message you.
  Powers the wizard and suggestions. (native inbox reader + `ServiceDetector`)
- **4-step rule wizard** — Category → detected services → recipient → simple
  schedule. Creating a rule is ~6 taps, essentially zero typing. Auto-generated
  rule names; banking/finance default to "ask me first".
- **Natural-language assistant** — "Forward Amazon orders to Rahul" → a ready
  rule, parsed fully on-device (offline). Matches recipients by name.
- **Proactive suggestions** — "Review ICICI OTPs?" / "Forward Myntra updates?"
  generated from real inbox activity, risk-aware (high-risk → approval).
- **Native contacts picker** — pick recipients from the address book (search,
  multi-select, phone chooser) instead of typing name/phone/email.
- **CA / accountant flow** — one guided flow to forward financial messages to an
  accountant with an auto-expiring window (Today / week / month / until off).
- **Working app lock** — PIN (salted hash in keystore) + biometric (fingerprint/
  face), with cold-launch and background-timeout gating (immediate/1/5/30 min).
- **Real payments** — Razorpay checkout with premium activation; runs in a
  testable demo mode until a live key is supplied via `--dart-define`.
- **New categories** — Recharge, Insurance, Tax, Investments, Promotions, with
  ~35 new Indian brands (Zerodha, Groww, LIC, GSTN, …).
- **Usage-limit prompts** — friendly in-flow upgrade sheets when a free wall is
  hit (the 50-forward cap was already hard-enforced in the pipeline).

### Fixed
- Foreground SMS listener now auto-starts on launch when permitted (previously
  only started from the Settings toggle).
- "Reset app" now fully wipes rules, recipients, queue, history, subscription,
  and the lock PIN (was only clearing settings + history).
- Biometric/app-lock toggles were dead booleans — now they gate the app.

### Notes
- On-device hybrid classifier chosen over a bundled LLM — see
  `docs/AI_CLASSIFICATION.md` for the reasoning.
- Payments require a Razorpay key + server-side signature verification before a
  public launch (see `docs/BACKEND.md`).
- Google Play SMS-permission policy is unchanged — see `docs/FEASIBILITY.md`.

## 1.0.0 — Initial build
Core: clean architecture, classification, rule engine, offline queue, encrypted
storage, dashboard/history/rules/onboarding/settings, Android SMS layer.
