# Release Security (Phase 4)

Production-hardening notes for the **release** build of OTPBridge. This
complements `DEPLOYMENT.md` and `PLAY_STORE_CHECKLIST.md`.

## What is enabled today

| Control | Status | Where |
| --- | --- | --- |
| R8 code shrinking + obfuscation (`isMinifyEnabled`) | ✅ On | `android/app/build.gradle.kts` → `buildTypes.release` |
| Resource shrinking (`isShrinkResources`) | ✅ On | same |
| Keep rules (anti-reflection breakage) | ✅ On | `android/app/proguard-rules.pro` |
| Dart icon tree-shaking | ✅ On (default) | Flutter build |
| Release signing key | ⚠️ Debug keystore (placeholder) | `buildTypes.release.signingConfig` |
| Dart-level obfuscation (`--obfuscate`) | ❌ Not yet | see Next steps |
| Crash reporting | ❌ Not yet | see Next steps |

### Obfuscation / shrinking

The release build runs R8 with `proguard-android-optimize.txt` plus our own
`proguard-rules.pro`. R8 renames and strips unused Java/Kotlin classes and
methods, and `isShrinkResources` drops unreferenced Android resources.

The R8 rename map is written to
`build/app/outputs/mapping/release/mapping.txt` at every release build. **Keep
this file** for each shipped version — it is required to de-obfuscate any
native stack traces (upload it to Play Console under the app's version, or
archive it alongside the release artifact). It is not committed to the repo.

`proguard-rules.pro` is deliberately conservative: it keeps the Flutter
embedding, all app platform-channel classes, and the reflection-heavy plugin
surfaces (Razorpay + its bundled `proguard.annotation.**`, Hive adapters,
flutter_secure_storage/Tink, local_auth/BiometricPrompt, permission_handler,
flutter_local_notifications + its Gson models, flutter_contacts, dio/OkHttp,
shared_preferences, and the Kotlin runtime). If a future dependency crashes
only in release with a `ClassNotFoundException` / `NoSuchMethodError`, add a
targeted `-keep` for that package rather than disabling minify.

## Sensitive-logging policy

**OTP codes, SMS bodies, PINs, and full message classifications must never be
written to any log sink** (`print`, `debugPrint`, `dart:developer` `log`,
Android `Log.*`, `println`, stdout/stderr) — not even in debug builds, because
logcat is world-readable to other on-device tooling and can leak into crash
reports.

Current state (audited Phase 4):

- The Kotlin layer (`SmsReceiver`, `SmsListenerService`, `MainActivity`) reads
  SMS sender/body but **contains no logging statements** — message content is
  passed straight over the Flutter EventChannel and never logged.
- The Dart `lib/` tree contains **no logging statements at all** (no `print`,
  `debugPrint`, logger package, or telemetry). Nothing needed redaction.

If logging is ever added, follow these rules:

- Never log message `body`, extracted OTP codes, or PIN input.
- Sender/recipient numbers must be masked (e.g. `+91••••••1234`) if logged.
- Prefer counts/enums (e.g. "classified: transactional") over raw content.
- Gate any diagnostic logging behind `kDebugMode` and strip it before release.

## Next steps (not yet done — track these)

1. **Real release keystore.** Replace the debug-signing placeholder. Create a
   keystore, add `android/key.properties` (git-ignored) with
   `storeFile / storePassword / keyAlias / keyPassword`, load it in
   `build.gradle.kts`, and point `release.signingConfig` at it. The current
   `// TODO: real release keystore` marks the spot. **A Play Store upload
   signed with debug keys will be rejected.**

2. **Dart-level obfuscation.** Build with
   `flutter build apk --release --obfuscate --split-debug-info=build/debug-info`
   (or `appbundle`) to obfuscate the compiled Dart and emit a symbol directory.
   Archive the `debug-info` output per version to symbolicate Dart stack
   traces. Consider `--split-per-abi` to cut the ~56 MB fat-APK size.

3. **Crash reporting (future add — do not install yet).** Evaluate Sentry
   (`sentry_flutter`) or Firebase Crashlytics for release crash/ANR visibility.
   Whichever is chosen, wire up automatic upload of the R8 `mapping.txt` and
   the Dart `--split-debug-info` symbols so reports are de-obfuscated, and
   ensure the SDK is configured **not** to capture SMS/OTP content.
