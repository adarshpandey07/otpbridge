# OTPBridge — Play Store & App Store Readiness Checklist

## ⚠️ Blocker to resolve first

- [ ] **SMS permission strategy decided.** Requesting `RECEIVE_SMS`/`READ_SMS`
      for third-party OTP forwarding is **not an approved Play use-case**.
      Choose one before any public submission:
  - [ ] Direct-APK / internal-testing only (no public listing) — *default,
        works today*
  - [ ] Default-SMS-handler app (build a full SMS client; forwarding is a
        feature)
  - [ ] Notification-listener capture (`BIND_NOTIFICATION_LISTENER_SERVICE`)
        instead of the SMS permission group
  - See `docs/FEASIBILITY.md`.

## Legal & policy

- [ ] Privacy policy published at a public URL (mandatory for sensitive perms)
- [ ] Data safety form completed (declare SMS/collection, encryption at rest,
      no data sold)
- [ ] Permissions Declaration Form submitted (if requesting SMS perms) with a
      demo video showing the core user-benefit flow
- [ ] Prominent in-app disclosure + runtime consent before reading SMS
- [ ] Terms of Service
- [ ] Financial-OTP handling reviewed (recommend: banking transaction OTPs stay
      behind manual approval; consider disabling auto-forward for public build)
- [ ] Account deletion path (Play requires an in-app + web deletion route if you
      have accounts)

## Store listing assets

- [ ] App name, short description (80 chars), full description
- [ ] App icon 512×512 (adaptive icon: foreground + background)
- [ ] Feature graphic 1024×500
- [ ] Phone screenshots (min 2; use the polished dashboard/rules/history)
- [ ] 7-inch & 10-inch tablet screenshots (if supporting tablets)
- [ ] Promo video (optional but strongly recommended for a permission review)
- [ ] Category: Tools / Productivity. Content rating questionnaire done.

## Technical readiness

- [ ] `applicationId` finalized (`com.otpbridge.otpbridge` placeholder → set real)
- [ ] `versionCode` / `versionName` set and incremented
- [ ] Release signing configured; keystore backed up securely
- [ ] `minSdk 24`, `targetSdk` = latest required by Play
- [ ] `flutter build appbundle --release` succeeds
- [ ] ProGuard/R8 rules verified (no reflection breakage in release)
- [ ] App runs in release mode on a physical device
- [ ] `flutter analyze` clean; `flutter test` green
- [ ] Crash reporting wired (Crashlytics / Sentry) — recommended
- [ ] Foreground service type declared and justified (SMS listening)
- [ ] POST_NOTIFICATIONS runtime request handled (Android 13+)
- [ ] No `print`/debug logging of OTP contents anywhere
- [ ] Offline behavior verified (queue retries; no crashes without network)

## UX / quality (Material + accessibility)

- [ ] Light & dark themes verified
- [ ] Touch targets ≥ 48dp; safe areas respected
- [ ] Text scales (Dynamic Type / large font) without breakage
- [ ] Contrast ≥ 4.5:1 for body text in both themes
- [ ] Onboarding explains permissions honestly
- [ ] Empty states and error states present on every screen
- [ ] Back navigation predictable; deep links to key screens

## iOS App Store (companion)

- [ ] App clearly positioned as companion (no SMS-reading claims)
- [ ] `NSFaceIDUsageDescription` and any other usage strings set
- [ ] App Tracking Transparency (if any tracking) — otherwise declare none
- [ ] Screenshots for each required device size
- [ ] Privacy nutrition labels completed

## Pre-launch (Play Console)

- [ ] Internal testing track validated with real testers
- [ ] Pre-launch report (automated device testing) reviewed
- [ ] Closed testing → gather feedback → promote to production
- [ ] Staged rollout (e.g. 10% → 50% → 100%)
