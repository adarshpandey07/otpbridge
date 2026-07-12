# OTPBridge — Feasibility & Product Reality Check

This is an honest engineering + product assessment. OTPBridge is technically
buildable and genuinely useful, but **the single largest risk is Google Play
policy, not code.** Read this before planning a public launch.

---

## 1. The core constraint: Play Store SMS permissions

Google restricts the `READ_SMS` / `RECEIVE_SMS` permission group. Since 2019,
**only an app that is the user's default SMS handler** — or one that qualifies
for a narrow set of declared exception use-cases — may request these
permissions and pass review. The permitted exception use-cases are a fixed
list (default handler, backup/restore, sync, automobile, connected device,
OTP-with-user-consent for *your own* app's flows, etc.).

**"Forward other apps' OTPs to a third party" is not on the approved list.** A
straightforward submission that requests `RECEIVE_SMS` for this purpose is at
high risk of rejection, and repeated rejections can jeopardize the developer
account.

### What this means practically

| Path | Viability | Notes |
|------|-----------|-------|
| Public Play Store listing requesting RECEIVE_SMS for OTP forwarding | ❌ High rejection risk | Not an approved exception use-case |
| Become the **default SMS app**, forwarding as a feature of a full messaging app | ⚠️ Possible | Huge scope increase; you must build a real SMS client; still needs a Declaration |
| **Sideload / enterprise / MDM distribution** (APK outside Play) | ✅ Works today | Your own device, family, org-managed fleets. No Play review. This build targets exactly this. |
| **Notification-listener** approach (read the OTP from the notification, not the SMS DB) | ⚠️ Grey area | `BIND_NOTIFICATION_LISTENER_SERVICE` avoids the SMS permission group but has its own Play scrutiny and is less reliable |
| iOS App Store | ❌ for auto-read | iOS sandbox forbids third-party SMS reading entirely (see §3) |

### Recommendation
- **For your stated goal ("deploy to Play Store, test it now"):** ship this as
  a **direct-APK / internal-testing** build first. It is fully functional for
  you, your family, or an organization you control. This is the realistic,
  compliant-by-avoidance path and it works immediately.
- **For a true public Play launch:** plan to either (a) pivot to a **default
  SMS handler** app where selective forwarding is one feature, or (b) use the
  **Notification Listener** capture path, and submit a **Permissions
  Declaration Form** with a crisp, user-benefit justification and a demo video.
  Budget for iteration with the review team. Treat this as a product/legal
  workstream, not a coding task.

The codebase is deliberately structured so this pivot is cheap: SMS capture is
behind the `SmsGateway` interface. A `NotificationListenerSmsGateway` or
`DefaultHandlerSmsGateway` can be dropped in without touching the pipeline,
rules, queue, or UI.

---

## 2. Second constraint: sending SMS costs and carrier limits

Forwarding via the device's own SIM (`SmsManager`) works but:
- Each forward is a **billable SMS** on the sender's plan.
- Android rate-limits app-initiated SMS (roughly ~30 messages / 30 min before
  the system prompts the user), which is fine for OTP volumes but not for bulk.
- Some carriers/regions restrict app-sent SMS.

This is why the architecture treats **channel** as pluggable
(`ForwardChannelPlugin`). For scale or cost control, WhatsApp Business API,
Telegram bot, email (SMTP), or push-to-companion-device are better long-term
channels than raw SMS. SMS is the v1 default because it needs no recipient-side
install.

---

## 3. iOS reality

iOS **does not permit** third-party apps to read arbitrary incoming SMS. The
only OTP-adjacent APIs are:
- **AutoFill** (`oneTimeCode` text content type) — fills an OTP into *your own*
  app's field; cannot forward.
- **Messages Filter extension** (`ILMessageFilterExtension`) — can classify
  unknown-sender SMS as spam/transaction, but cannot exfiltrate/forward them.

Therefore iOS is a **companion app**: account, rules, recipients, history,
analytics, notifications, and (future) receiving forwards from an Android
"sender" device via the backend. The app is built with this split baked into
`PlatformCapabilities`, so the same Flutter codebase runs on both.

---

## 4. Privacy, security & trust

Reading OTPs is inherently sensitive. Mitigations built in / recommended:
- **On-device classification** — the hybrid engine works fully offline; no OTP
  needs to leave the device to be categorized.
- **AES-encrypted local storage** (Hive + keystore-held key).
- **App lock / biometric** gate, OTP masking in notifications, high-risk
  manual-approval flow, replay/duplicate protection.
- **Data minimization** — don't sync raw OTPs to any backend; sync only rules,
  recipients, and redacted history if cloud sync is enabled.
- A clear, prominent **privacy policy** is mandatory for Play submission when
  any sensitive permission is involved.

Financial-OTP forwarding is the highest-liability feature. The default posture
(banking/UPI/card OTPs above a cap require explicit approval, and high-risk
categories default to approval) is intentional. Consider disabling automatic
forwarding of banking-transaction OTPs entirely for a public release.

---

## 5. Functional feasibility (the parts that just work)

These are solved and shipping in this build:
- Hybrid **classification** (rules + regex + brand catalog), offline, with
  confidence scoring and structured extraction (OTP, amount, merchant, type).
- **Rule engine**: priority ordering, category/brand/sender/keyword matching,
  time & date schedules, amount caps, security escalation.
- **Offline queue**: persistent, exponential backoff, dedupe, delivery states.
- **Subscription** gating (free caps vs premium), **approval** flow, **history/
  analytics**, **notifications**, encrypted storage, clean architecture,
  Riverpod + GoRouter, light/dark design system, tests.

## 6. Verdict

- **As a personal / family / enterprise-controlled tool distributed by APK or
  MDM: fully feasible today.** This build delivers it.
- **As a public consumer app on Play/App Store: feasible only with a policy
  strategy** (default-SMS-handler or notification-listener + declaration on
  Android; companion-only on iOS). Plan that as a dedicated track.
- Do **not** auto-forward banking transaction OTPs in a public build without
  legal review — keep them behind manual approval.

The engineering is the easy 70%. The policy/trust/compliance work is the hard
30% that determines whether this reaches a public store.
