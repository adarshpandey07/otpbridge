# OTPBridge — Play Store SMS Compliance Report (Phase 3)

**Scope:** Google Play policy analysis for OTPBridge — an app that classifies
incoming OTP SMS and forwards selected messages to chosen recipients per
user-defined rules. This is the release-decision document. It builds on
`FEASIBILITY.md` (product reality) and `ARCHITECTURE.md` (how the pieces fit);
it does not repeat them.

**Honesty contract:** this report does **not** propose bypassing Play policy,
Play review, or Google Play Protect. Where a capability cannot be shipped
compliantly, it says so plainly and routes it to a non-Play distribution channel
where the developer/organization owns the consent and liability directly.

**Policy basis (verified July 2026):**
- *Use of SMS or Call Log permission groups* — Play Console Help, answer 10208820.
- *Understanding foreground service and full-screen intent requirements* — Play
  Console Help, answer 13392821.
- *Permissions and APIs that Access Sensitive Information* — answer 16558241.

---

## 0. Bottom line up front

1. **The headline feature — "read other apps' OTPs and forward them to a third
   party" — is not an approved use of the SMS permission group and will very
   likely be rejected on any public Play track.** It also collides with the
   Spyware policy's explicit prohibition on *"exfiltration of data that is not
   related to policy-compliant functionality."* Forwarding SMS content off-device
   to a chosen recipient is precisely that pattern.
2. There is a **second, independent blocker** already in the manifest:
   `FOREGROUND_SERVICE_SPECIAL_USE`. `specialUse` is reviewed per submission and
   Google's stated posture is that it is "reserved for system applications and
   specific system integrations." An SMS-listener foreground service is unlikely
   to clear that bar and should not ship in a Play build.
3. **Recommended split:** ship a Play-compliant *baseline* build that holds **no
   SMS permission group at all** (user-mediated capture: share-to-app, paste,
   SMS User Consent one-shot), and keep the **auto-read power feature as an
   Android-only, off-by-default, prominently-disclosed** capability distributed
   by **direct APK / MDM / enterprise EMM** — never uploaded to Play. The
   existing `SmsGateway` abstraction makes this a one-provider swap.
4. **Do not auto-forward financial/banking transaction OTPs in any public or
   consumer build.** That is the highest-liability path and should be hard-
   disabled in the Play build, not merely capped.

---

## 1. The policy that actually governs this app

### 1a. SMS & Call Log Permissions policy — the exhaustive approved list

Since the 2019 restriction, Play grants the SMS/Call Log permission group only to
apps that are a **default handler** or that qualify for a **named exception** and
pass a manual **Permissions Declaration** review. The current (verified July
2026) permitted uses are:

**Default-handler uses (the app must be set as the default and the feature must
require it):**
- Default **SMS** handler — receive/send SMS
- Default **Phone** handler — call management
- Default **Assistant** handler — real-time SMS translation/replies

**Named exception use cases (temporary exception, subject to declaration review,
granted only where there is "no alternative method"):**
- Account verification via **phone call**
- Anti-SMS phishing ("smishing")
- **Backup and restore** for users
- **Caller ID**, spam detection and/or spam blocking
- **Connected-device companion** apps
- **Cross-device synchronization or transfer**
- **Device automation**
- **Enterprise archive and CRM**
- In-vehicle hands-free use
- Physical safety / emergency alerts
- Proxy calls
- SMS Cell Broadcast
- **SMS-based financial transactions**
- Call-based authentication in banking
- **SMS-based money management**
- Write and show call history
- System Services with the `SYSTEM_UI_INTELLIGENCE` role

**"Read another app's OTP and forward it to a person you chose" appears nowhere
on this list.** The closest-sounding entries do not apply:
- *SMS-based financial transactions / money management* cover apps that transact
  or manage money *for the user via SMS with the app's own service*, not a relay
  of arbitrary senders' codes to a third party.
- *Cross-device sync / connected-device companion* covers syncing a user's own
  messages to the same user's other device (Wear, Auto, a paired PC) — not
  forwarding to a different person.

The policy is also explicit that certain adjacent uses are **invalid**:
*account verification via SMS, content sharing/invites, and contact
prioritization* (when not the default handler). OTP forwarding is nearer to
"content sharing" than to any permitted exception.

**On OTP auto-fill specifically:** the policy directs developers to use the
**SMS Retriever API** for verification "without requiring the user to manually
type verification codes and without requiring any extra app permissions." In
other words, even *"OTP for your own app"* is **not** a valid reason to hold
`RECEIVE_SMS`/`READ_SMS` — Google expects Retriever/User-Consent instead. Any
framing of OTPBridge as "OTP-with-consent for your own flows" does not unlock the
permission group.

**Net:** a Play submission requesting `RECEIVE_SMS`/`READ_SMS` for OTP forwarding
is at **high risk of rejection**, and repeated rejections — plus the Spyware-
policy exfiltration angle — put the **developer account** at enforcement risk
(warnings → app removal → possible termination). This matches `FEASIBILITY.md §1`
and is the reason the manifest carries the warning comment it does.

### 1b. The second blocker — `FOREGROUND_SERVICE_SPECIAL_USE`

Independent of SMS, the manifest declares `SmsListenerService` with
`foregroundServiceType="specialUse"`. For apps targeting Android 14+, **every**
foreground-service type must be declared on the Play Console *App content* page
with a description **and a demo video**, and is reviewed. Google's reviewer
guidance states `specialUse` is "reserved for system applications and specific
system integrations" — a consumer SMS-listener is a weak fit and likely to be
pushed back. This is a *second* review gate a Play build would have to clear even
if the SMS question were somehow resolved. The clean answer is to **not ship the
listener FGS on Play at all** (see §4).

---

## 2. Permission justification table

Every permission currently in `android/app/src/main/AndroidManifest.xml`, judged
against the policy above:

| Permission | Why the app wants it | Justifiable on public Play? | Verdict |
|---|---|---|---|
| `RECEIVE_SMS` | Wake on each incoming SMS to classify/forward | **No** — not an approved exception; core blocker | 🚫 Blocker |
| `READ_SMS` | `readInbox()` bulk scan for service detection; read message bodies | **No** — bulk read is *higher* scrutiny than receive; not approved | 🚫 Blocker |
| `SEND_SMS` | Forward the OTP over the device radio (`SmsChannelPlugin`) | **No** — same restricted group; needs default-handler/declaration | 🚫 Blocker |
| `READ_CONTACTS` | Native picker to choose recipients | Yes, *if* used only via user-initiated picker with disclosure | ⚠️ Prefer the system Contacts Picker (no permission) |
| `POST_NOTIFICATIONS` | Approval prompts, delivery status (Android 13+) | Yes — standard runtime permission | ✅ Safe |
| `FOREGROUND_SERVICE` | Keep the SMS listener alive | Only meaningful with the SMS listener; tied to the blocker | ⚠️ Drop on Play |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Type for the SMS listener FGS | Reviewed; `specialUse` "reserved for system apps"; weak fit | 🚫 Second blocker |
| `RECEIVE_BOOT_COMPLETED` | Restart the listener after reboot | Only for the listener; tied to the blocker | ⚠️ Drop on Play |
| `WAKE_LOCK` | Hold wake during processing | Benign, but only needed by the listener path | ⚠️ Drop on Play |
| `USE_BIOMETRIC` | App-lock (fingerprint/face) | Yes — normal, low-risk | ✅ Safe |
| `BROADCAST_SMS` (receiver guard) | System-only trigger of `SmsReceiver` | Part of the SMS receive path | 🚫 Tied to blocker |

**Reading of the table:** the blockers are `RECEIVE_SMS`, `READ_SMS`, `SEND_SMS`
and `FOREGROUND_SERVICE_SPECIAL_USE` (plus the `SmsReceiver` and the `SEND_SMS`-
based `SmsChannelPlugin`). `POST_NOTIFICATIONS` and `USE_BIOMETRIC` are fine.
`READ_CONTACTS` is *avoidable* — the Android system Contacts Picker returns a
single contact with **no** permission and is the recommended pattern for a Play
build.

---

## 3. Less-sensitive / user-mediated alternatives

Each option below is evaluated for whether it lets OTPBridge do its job **and**
what it costs.

### 3a. SMS Retriever API — no permission, but self-addressed only
- **What it is:** fully automatic, zero-tap read of one incoming message that
  contains your app's 11-char hash string. No SMS permission.
- **Fit for OTPBridge:** **none for the core feature.** Retriever only reads
  messages you had sent to *your own* app (you control the sender template/hash).
  It cannot read a bank's or a third-party app's OTP. Cannot forward silently.

### 3b. SMS User Consent API — no permission, one message, user-tapped
- **What it is:** you call `startSmsUserConsent(sender?)`; the next OTP-shaped
  message within ~5 minutes triggers a **system consent dialog** showing the
  message; if the user taps *Allow*, your app receives that one message's text.
  No SMS permission.
- **Fit:** enables a **user-mediated "grab the code that just arrived"** flow —
  the user taps once per code, then OTPBridge classifies and forwards it. It
  **cannot** run continuously in the background, cannot capture without the
  per-message tap, and cannot silently forward arbitrary OTPs. This is a genuine
  feature reduction, but it is fully Play-compliant and needs no permission.

### 3c. Notification Listener (`BIND_NOTIFICATION_LISTENER_SERVICE`) — grey area
- **What it is:** read the OTP from the *notification* the SMS app posts, rather
  than from the SMS database. Avoids the SMS permission group.
- **Policy:** its own review gate; notification access must be core to the app,
  disclosed, and Google has tightened scrutiny. Forwarding notification contents
  to a third party runs into the **same Spyware/exfiltration reasoning** as SMS.
  Not a safe "loophole."
- **Technical:** unreliable — depends on the messaging app posting the full text
  (OEMs truncate; secure/hidden-content notifications show nothing; notifications
  can be dismissed before capture). Grey **and** fragile. Not recommended as the
  public strategy.

### 3d. Default SMS handler — allowed, but a different (huge) product
- **What it is:** register OTPBridge as the user's default SMS app; default
  handlers may hold `READ_SMS`/`RECEIVE_SMS`/`SEND_SMS`. Forwarding becomes one
  feature of a full messaging client.
- **Cost:** you must build and maintain a **real SMS client** (conversations,
  compose, MMS, RCS expectations, delivery reports), the user must switch their
  default app, and you still submit a declaration. Even then, a client whose
  *primary* purpose is relaying codes to third parties invites the exfiltration
  read. High scope, high friction (one default app per device), uncertain payoff.

### 3e. Manual / share-to-app / paste — fully compliant, zero SMS permission
- **What it is:** the user receives the OTP in their normal SMS app and either
  (a) **Share → OTPBridge** via an `ACTION_SEND` text intent, (b) long-press-copy
  → paste into OTPBridge, or (c) uses the **User Consent** one-shot (3b).
  OTPBridge then classifies and forwards per the same rules/queue/history
  pipeline. **No SMS permission at all.**
- **Cost:** not automatic — one user action per OTP. For the delegation use cases
  (the CA/accountant flow in `features/ca_flow`, family sharing) a "share the
  code" gesture is acceptable and honest. The manifest already declares the
  `PROCESS_TEXT` query; adding an `ACTION_SEND`/`text/plain` intent-filter to
  receive shared text is trivial. **This is the recommended public baseline.**

### 3f. Direct APK / MDM / enterprise EMM — no Play review
- **What it is:** distribute the full auto-read build as a signed APK, or push it
  via Intune / Workspace ONE / managed Google Play (private app) to devices the
  user or organization controls.
- **Cost / honesty:** no Play policy review applies, so auto-read works. But this
  is **not** a way to dodge scrutiny of a consumer app — it is legitimate only
  for **your own / family / org-managed** devices with real consent. **Google
  Play Protect still scans sideloaded apps** and may warn users about an app that
  reads SMS and sends data off-device; that warning is expected and must **not**
  be engineered around. For fleets, handle it via MDM allowlisting / managed Play
  Protect policy, not by hiding behavior.

---

## 4. Recommended architecture — a staged, two-build plan

Ship **two Android product flavors** from the one codebase. The domain layer,
rules, queue, classification, history, and UI are identical; only the SMS-capture
strategy and the manifest differ.

### Flavor A — `play` (public, compliant baseline)
- **Manifest holds no SMS permission group.** Move `RECEIVE_SMS`, `READ_SMS`,
  `SEND_SMS`, `BROADCAST_SMS`, `SmsReceiver`, `SmsListenerService`,
  `FOREGROUND_SERVICE*`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK` **out of
  `src/main/AndroidManifest.xml`** into `src/full/AndroidManifest.xml`. The Play
  build then never even *declares* the restricted permissions — the cleanest
  possible signal to review.
- **Capture:** user-mediated only — `ACTION_SEND` share target + paste + SMS User
  Consent one-shot. Implement as a new `SmsGateway` (e.g.
  `UserMediatedSmsGateway`) or extend `CompanionSmsGateway` with a capture entry
  point. `capabilities().canReadSms = false`.
- **Forwarding channel:** **not** `SEND_SMS` (also restricted). Forward via a
  non-SMS `ForwardChannelPlugin` — WhatsApp/Telegram/email/push — or the OS share
  sheet. This is exactly the pluggable-channel design in `FEASIBILITY.md §2` and
  the `ChannelRegistry` extension point.
- **Defaults:** `listeningEnabled = false`; financial-category auto-forward
  hard-disabled; no `readInbox()` bulk scan.

### Flavor B — `full` (direct APK / MDM / enterprise power feature)
- Adds the SMS permission group, `SmsReceiver`, `SmsListenerService`, and wires
  `AndroidSmsGateway`.
- **Off by default** (`listeningEnabled = false`) and gated behind a mandatory
  prominent-disclosure + explicit-consent screen (§5) before the first read.
- **Never uploaded to any Play track.** Distributed by signed APK / MDM only.

### How the existing abstraction already supports this
The swap point is a single line and a single provider:
- `lib/main.dart:26` — `Platform.isAndroid ? AndroidSmsGateway() : CompanionSmsGateway()`.
  Make it **flavor-aware** (compile-time flavor constant / build config): the
  `play` flavor injects `UserMediatedSmsGateway`, the `full` flavor injects
  `AndroidSmsGateway`.
- `lib/app/providers.dart:34` — `smsGatewayProvider` is the one override target;
  everything downstream (`SmsPipeline`, `RuleEngine`, `ForwardingQueue`,
  `ServiceDetector`, every screen) depends only on the `SmsGateway` **interface**
  in `lib/domain/services/sms_gateway.dart`. Per `ARCHITECTURE.md`'s extension-
  point table, swapping the capture strategy touches **no** pipeline, rules,
  queue, or UI code. The compliant baseline is therefore a configuration change,
  not a rewrite.

---

## 5. Required disclosures

Applies in full to the `full` (auto-read) build, and — for the capture the user
does perform — to the `play` build too.

### 5a. Prominent disclosure + runtime consent (before any SMS access)
Google requires a **standalone, in-context disclosure** shown **before** the
runtime permission request (and before any access), that:
- Names the app and states it will access **SMS messages**;
- Explains **what** is accessed and **why** ("to find OTP codes and forward the
  ones your rules select");
- States the data **will be sent to recipients you choose**;
- Requires **affirmative action** — a distinct "Enable auto-read" / "I agree"
  button — and is **not** satisfied by burying the notice in onboarding copy, the
  ToS, or the privacy policy.

**Current gap:** the onboarding "Permissions" page
(`lib/features/onboarding/onboarding_screen.dart`, `_permissionsPage`) requests
`Permission.sms` from a generic feature list with a "Continue"-style flow. That
is **not** a compliant prominent disclosure. Add a dedicated consent gate with
the language above and an explicit affirmative button, and **record consent**
(add `smsAutoReadConsentAt` + `disclosureVersionAccepted` to `AppSettings`; block
`AndroidSmsGateway.startListening()` until set).

### 5b. Privacy policy
Public URL, required whenever a sensitive permission is involved. Must describe:
what SMS data is accessed, on-device processing, that message content is
forwarded **to recipients the user designates**, retention, encryption, and the
deletion path.

### 5c. Data Safety declarations (Play Console)
- **Data collected:** *SMS messages (contents)* and *Contacts* (for recipient
  selection).
- **Purpose:** app functionality only.
- **Processing:** classification is **on-device** (state this).
- **Shared / transferred:** be honest — the app's purpose is to **transfer the
  selected OTP/message to a user-designated recipient**. Declare that message
  content may be sent to recipients the user chooses; **not** sold, **no** ad/
  analytics use of message content.
- **Encrypted at rest:** **yes** — Hive boxes use `HiveAesCipher` with a 256-bit
  key held in the platform keystore (`ARCHITECTURE.md` security model). Declare
  encryption in transit for the forward channel too.
- **Deletion:** in-app **Reset app** (`localStore.wipeAll()`) and **Clear
  history** already exist (`settings_screen.dart` Data & privacy). Finish
  **Export history** (currently "coming soon") to complete the portability story.
  No user accounts exist yet, so no web-deletion URL is required — add one only if
  cloud sync/accounts land later.

### 5d. Permissions Declaration Form + demo video
Only relevant if you ever request the SMS group on a Play track. Expect to submit
a written core-functionality justification **plus a demo video** of the user-
benefit flow. **Honest expectation: for OTP forwarding this is likely to be
rejected** (§1). The recommended `play` build **avoids needing this form at all.**

### 5e. Foreground-service declaration
Any FGS on a Play build must be declared on the *App content* page **with a demo
video** and is reviewed; `specialUse` draws extra scrutiny (§1b). The `play`
build should carry **no** SMS-listener FGS, removing this gate entirely.

---

## 6. Risk analysis

| Distribution path | Rejection likelihood | Account-level risk | Notes |
|---|---|---|---|
| Public Play — request `RECEIVE_SMS`/`READ_SMS` for OTP forwarding | **High** | **Med–High** | Not an approved use + Spyware exfiltration clause; repeat rejections escalate enforcement |
| Public Play — Notification-Listener capture + forward | **Med–High** | **Med** | Grey-area review, same exfiltration reasoning, technically fragile |
| Public Play — Default SMS handler + forwarding feature | **Med** | **Low–Med** | Allowed in principle but forwarding-to-third-party framing is risky; must build a full SMS client |
| Public Play — user-mediated (share/paste/User Consent), **no SMS group** | **Low** | **Low** | **Recommended public baseline** |
| Direct APK / MDM / enterprise — full auto-read | **N/A** (no Play review) | **N/A** (Play); user-trust + legal risk remain | **Recommended for the power feature**; Play Protect may still warn — do not evade |

**Financial-OTP liability (highest-severity item):** auto-forwarding
banking/UPI/card **transaction** OTPs to a third party can enable unauthorized
transactions, creates fraud and chargeback exposure, and likely violates banks'
terms and local financial regulations. The app already ships sane defaults —
`bankingAutoForwardCap = 5000` and `highRiskRequiresApproval = true`
(`AppSettings`) — but for any **public/consumer** build go further: **hard-
disable auto-forward of financial categories entirely** (keep manual approval as
the only route, or exclude them). Reserve any automatic financial forwarding for
the enterprise `full` build under explicit organizational consent. This aligns
with and strengthens `FEASIBILITY.md §4`.

---

## 7. Required changes checklist

- [ ] Add Android product flavors `play` and `full`; wire flavor-aware
      `SmsGateway` selection in `main.dart` and `smsGatewayProvider`.
- [ ] Move the SMS group + `SmsReceiver` + `SmsListenerService` + FGS/boot/wake
      permissions from `src/main/AndroidManifest.xml` to `src/full/`. Keep
      `src/main` free of `RECEIVE_SMS`/`READ_SMS`/`SEND_SMS`.
- [ ] `play` flavor: implement user-mediated capture — `ACTION_SEND` share
      target, paste, and SMS User Consent one-shot (`UserMediatedSmsGateway`).
- [ ] `play` flavor: forward via a non-SMS `ForwardChannelPlugin` (WhatsApp/
      Telegram/email/share sheet); **remove** `SEND_SMS` and the SMS send channel.
- [ ] `play` flavor: hard-disable auto-forward of financial categories; remove
      the `readInbox()` bulk inbox scan.
- [ ] `AppSettings`: default `listeningEnabled = false`; add `smsAutoReadConsentAt`
      and `disclosureVersionAccepted`.
- [ ] Add a dedicated **prominent-disclosure consent screen**; block
      `AndroidSmsGateway.startListening()` / auto-read until consent is recorded.
      Reframe the onboarding permissions page accordingly.
- [ ] Prefer the system **Contacts Picker** (no `READ_CONTACTS`) in the `play`
      build.
- [ ] Do **not** declare an SMS-listener FGS in the `play` build.
- [ ] Publish a **privacy policy URL**; complete the **Data Safety** form per §5c.
- [ ] Finish **Export history** (currently "coming soon") for the deletion/
      portability story.
- [ ] Verify **no OTP contents are logged** anywhere (`print`/debug).
- [ ] Finalize `applicationId` (placeholder `com.otpbridge.otpbridge`).
- [ ] For the `full` build: document the MDM/EMM deployment + consent process;
      do not attempt to suppress Play Protect warnings.

---

## 8. Remaining limitations (stated honestly)

- **Silent, automatic, background forwarding of arbitrary third-party OTPs cannot
  be shipped on the public Play Store — full stop.** No API + policy combination
  permits it. The `play` build is a genuinely *reduced* product (one user action
  per code), not a workaround that quietly restores auto-read.
- **SMS Retriever / SMS User Consent cannot forward silently** and cannot capture
  continuously in the background; they are per-message, user-tapped.
- **Notification-Listener auto-read** is both a policy grey area *and* technically
  unreliable; it is not a safe substitute for the SMS permission and is not
  recommended as the public strategy.
- **`SEND_SMS` forwarding is also restricted on Play** — the `play` build must
  forward over non-SMS channels or the OS share sheet.
- **iOS can never auto-read** (sandbox forbids third-party SMS reading); it stays
  companion-only per `FEASIBILITY.md §3`.
- **The auto-read power feature can only live off-Play** (direct APK / MDM /
  enterprise), where the developer or organization carries the consent and legal
  responsibility directly — and even there, **Play Protect may warn users, which
  is expected and must not be circumvented.**

---

### Sources
- [Use of SMS or Call Log permission groups — Play Console Help](https://support.google.com/googleplay/android-developer/answer/10208820)
- [Understanding foreground service and full-screen intent requirements — Play Console Help](https://support.google.com/googleplay/android-developer/answer/13392821)
- [Permissions and APIs that Access Sensitive Information — Play Console Help](https://support.google.com/googleplay/android-developer/answer/16558241)
- [SMS Retriever API / SMS User Consent API — Android Developers](https://developers.google.com/identity/sms-retriever/overview)
</content>
</invoke>
