# OTPBridge — Deployment Guide

## Prerequisites

- Flutter 3.29+ (stable), Dart 3.7+
- JDK 17 (Android builds)
- Android SDK, `minSdk 24`, `targetSdk` = latest
- A keystore for release signing
- (iOS companion) Xcode 15+, an Apple Developer account

## 1. Versioning

`pubspec.yaml` → `version: 1.0.0+1` (`<semver>+<buildNumber>`). Bump the build
number on every store upload. CI can inject it: `--build-number=$(date +%s)`.

## 2. Android release signing

Create `android/key.properties` (git-ignored):
```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```
Generate the keystore:
```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
`android/app/build.gradle.kts` reads `key.properties` for the `release`
signingConfig. **Back up the keystore + passwords** — losing them means you can
never update the app on Play.

## 3. Build

```bash
flutter pub get
flutter analyze
flutter test

# Direct-distribution / internal testing APK (recommended first path):
flutter build apk --release
#   → build/app/outputs/flutter-apk/app-release.apk

# Play Store bundle:
flutter build appbundle --release
#   → build/app/outputs/bundle/release/app-release.aab

# Split-per-ABI APKs (smaller downloads):
flutter build apk --release --split-per-abi
```

## 4. Distribution paths

| Path | Command / channel | When |
|------|-------------------|------|
| **Direct APK** | share `app-release.apk` | you, family, an org you control — no store review, works today |
| **Play Internal testing** | upload `.aab` to Play Console → Internal testing | small tester group, still needs SMS-permission declaration if requesting RECEIVE_SMS |
| **Play Closed/Open/Production** | promote the track | requires the policy strategy in `FEASIBILITY.md` |
| **MDM / EMM** | push APK via Intune/Workspace ONE etc. | enterprise fleets |

> Requesting `RECEIVE_SMS`/`READ_SMS` on any Play track needs the **Permissions
> Declaration Form** + a demo video + privacy policy URL. See
> `PLAY_STORE_CHECKLIST.md`. For the direct-APK path none of that applies.

## 5. iOS companion

```bash
flutter build ipa --release
```
iOS ships **without** SMS auto-reading (sandbox forbids it). Ensure the app
gracefully shows companion mode. Submit via Transporter / Xcode. App Store
review will reject any claim of reading other apps' SMS — describe it as a
rules/history companion.

## 6. CI/CD

A ready GitHub Actions workflow is at `.github/workflows/ci.yaml`:
- On PR/push: `flutter pub get` → `flutter analyze` → `flutter test`.
- On tag `v*`: build `.aab` + APK, sign (keystore from repo secrets:
  `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`), upload
  artifacts. Optionally add the Play publisher action for auto-upload to an
  internal track.

Secrets to configure: `KEYSTORE_BASE64` (base64 of the `.jks`),
`STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`, and (for auto-publish)
`PLAY_SERVICE_ACCOUNT_JSON`.

## 7. Pre-release smoke test

```bash
flutter run --release        # on a physical Android device
```
Verify: onboarding + permissions, load sample data, create a rule, send a test
SMS to the device from another phone, confirm classify → rule → forward →
history, toggle airplane mode to confirm the queue retries, dark mode, app lock.

## 8. Post-release

- Monitor Play Console vitals (ANRs/crashes) and the SMS-permission review
  status.
- Keep the keystore + `key.properties` in a password manager / secure vault.
- Tag releases (`git tag v1.0.0`) so CI produces reproducible artifacts.
