# Store Listing — Phase 11

Paste-ready Google Play (and companion iOS) listing assets for the app rebranded
per [`BRANDING.md`](BRANDING.md). Written with **Keyward** as the working brand;
**Verixa** and **Trustbridge** variants are given for every title/short-desc
block so the final name choice stays reversible. Swap the brand token throughout
before publishing.

> **Policy prerequisite (read [`FEASIBILITY.md`](FEASIBILITY.md) first).**
> Requesting `RECEIVE_SMS`/`READ_SMS` for third-party OTP forwarding is **not an
> approved public Play use-case**. This listing copy is safe and honest for
> either compliant path — (a) internal/closed testing & direct-APK distribution,
> or (b) a public launch via the default-SMS-handler or notification-listener
> strategy plus a Permissions Declaration. The copy deliberately says
> "verification codes *you* choose" and never claims to read other apps'
> messages. If you ship the notification-listener path, change permission-facing
> wording from "reads your SMS" to "reads verification notifications."
> **Do not auto-forward banking/transaction codes in a public build** — keep
> them behind manual approval (already the default).

---

## 1. App title (≤ 30 chars) + short description (≤ 80 chars)

### Title options (character count in parentheses)

| Brand | Title | Chars |
|-------|-------|-------|
| Keyward | `Keyward: Secure Code Relay` | 26 |
| Keyward | `Keyward – Verify & Relay` | 24 |
| Keyward | `Keyward: OTP & Auth Vault` | 25 |
| Verixa | `Verixa: Secure Code Relay` | 25 |
| Trustbridge | `Trustbridge: Secure OTPs` | 24 |

Recommended: **`Keyward: Secure Code Relay`** — brand + category + benefit, no
policy-risky verb.

### Short description options (≤ 80 chars)

1. `Forward the OTPs you choose to people you trust — encrypted, on-device.` (71)
2. `Rule-based OTP forwarding. On-device, encrypted, you're in control.` (67)
3. `Smart, private OTP forwarding — processed on your device, not the cloud.` (72)
4. `Route verification codes to the right person, on your terms.` (60)

Recommended: **#1** (benefit + privacy proof in one line).

---

## 2. Full description (≤ 4000 chars)

> Paste-ready below (~2,650 chars incl. spacing). Replace **Keyward** with the
> final brand. Play renders limited formatting — the ALL-CAPS mini-headers and
> bullet dashes below survive; keep line breaks.

```
Keyward routes the verification codes YOU choose to the people YOU trust — automatically, on your terms, and processed privately on your own device.

No more forwarding OTPs by hand. No more reading a code aloud over the phone. Set a rule once — "Send my Amazon delivery codes to Rahul, 10 AM–7 PM" — and Keyward does the rest, with security built in from the ground up.

WHY KEYWARD
• You're in control — you decide exactly which codes go where, to whom, and when. Nothing is forwarded that you didn't set up.
• Private by design — codes are classified on your device by an offline engine. Your messages aren't sent to our servers to be read.
• Encrypted storage — rules, recipients, and history are stored with AES encryption, protected by a key held in your device's secure keystore.
• App lock — gate the app behind a PIN or your fingerprint/face.
• Built-in caution for sensitive codes — banking and payment codes default to "ask me first," with a manual-approval step and a live countdown.

HOW IT WORKS
1. Pick a category or an app (Keyward suggests the ones that actually message you).
2. Choose a recipient from your contacts.
3. Set a simple schedule — today, this week, business hours, or always.
That's it. When a matching code arrives, Keyward classifies it on-device, checks your rule, and forwards it to the right person. High-risk codes wait for your approval.

SMART, NOT NOISY
• On-device AI sorts codes by brand, category, amount, and risk — fully offline.
• A plain-language assistant turns "forward Myntra updates to Mom" into a ready rule.
• A searchable history timeline shows every code, where it went, and its delivery status.
• An offline queue retries reliably through flight mode, weak signal, or a reboot.

PRIVACY & TRUST
Keyward is built around data minimization. Verification codes are processed on your device — they are not uploaded to us to be read or sold. You choose your recipients, you approve sensitive codes, and you can wipe every rule, recipient, and record from the app at any time. You need permission to access messages so the app can detect and route the codes you've set up; we ask for it transparently and use it only for that purpose. Please only forward codes that are yours to share.

FREE & PREMIUM
Start free: up to 50 forwards a month, 1 recipient, and 3 rules. Upgrade to Premium (₹99/month) for unlimited forwards, unlimited recipients and rules, and advanced scheduling and security controls.

Keyward — your codes, your rules, delivered.
```

**Legal/honesty guardrails baked into the copy:** on-device processing stated
plainly; encryption named; user control and consent emphasized; "only forward
codes that are yours to share"; banking codes gated; no claim of reading other
apps' or other people's messages; subscription price and free caps disclosed.

---

## 3. Keywords / ASO guidance

Play ranks primarily on the **title, short description, and full description** —
there is no separate keyword field (that's iOS). Weave these naturally into the
copy above (already done for the high-value ones); don't keyword-stuff.

- **Primary (must appear in title/short/first 2 lines):** OTP, verification code,
  forward, secure, on-device, private, encrypted, rules.
- **Secondary (weave into body):** authentication, 2FA / two-factor code, one-time
  password, SMS forwarding, auto-forward, passcode, contacts, schedule, approval,
  offline, biometric / app lock.
- **Long-tail / intent:** "forward OTP to another number," "send verification
  code to family," "rule-based SMS forwarding," "OTP to WhatsApp/Telegram"
  (roadmap channels — only mention once shipped).
- **Avoid (policy/ranking risk):** "read others' SMS," "spy," "intercept,"
  "hack," "bypass OTP," "track messages." These invite rejection and the wrong
  audience.

**iOS App Store keyword field (100 chars, comma-separated, no spaces):**
`otp,2fa,verification,code,forward,authenticator,passcode,secure,sms,private,encrypted,relay`
(iOS is companion — no auto-read claims; describe it as rules/recipients/history/
approvals hub.)

---

## 4. Feature graphic + screenshots

### Feature graphic (1024×500 px, no alpha)

- Background: indigo→indigo-600 (`#4F46E5`→`#4338CA`) or a clean slate field.
- Left: the app icon/wordmark (Keyward) + tagline **"Your codes. Your rules.
  Delivered."**
- Right: a single stylized phone showing a masked code card (`••• 4821` in
  JetBrains Mono) flowing along a short "bridge" arc to a recipient avatar.
- One trust chip: **"On-device · Encrypted."** Keep it uncluttered — no more than
  ~7 words of text. Legible as a thumbnail; safe margins ~48px; avoid text near
  edges (Play crops on some surfaces).

### Phone screenshots (capture 5–8; 1080×1920 or device-native, PNG)

Frame each in a device mockup with a one-line caption banner in Inter SemiBold.

| # | Screen | Caption |
|---|--------|---------|
| 1 | Dashboard (stats + recent activity) | "See every code at a glance." |
| 2 | Rule wizard (4-step: category → service → recipient → schedule) | "Set a rule in about six taps." |
| 3 | Natural-language assistant | "Just say what you want. On-device." |
| 4 | Manual approval (high-risk code + live countdown) | "Sensitive codes wait for your OK." |
| 5 | History timeline (searchable, delivery status) | "A clear trail of what went where." |
| 6 | Security / app lock (PIN + biometric, encryption) | "Locked, encrypted, on your device." |
| 7 | Paywall / Premium | "Free to start. Premium for power users." |
| 8 (opt.) | Contacts picker / recipient setup | "Forward to people you choose." |

Minimum for Play is 2; ship all light-theme by default, and consider a dark-theme
variant of #1 and #6 to showcase the dark palette. Add 7-inch and 10-inch tablet
sets only if you enable tablet support. A 30-second promo video is **strongly
recommended** if you submit a Permissions Declaration — record the wizard →
matching code → approval → delivery flow.

---

## 5. Data Safety form answers

Fill this into Play Console ▸ App content ▸ Data safety. The guiding facts:
verification codes are **processed on-device and not transmitted to the
developer**; forwarding goes to a **recipient the user chose** (user-initiated,
not developer "sharing"); optional cloud sync (if enabled) carries only rules,
recipients, and **redacted** history — never raw codes.

**Section A — Security practices**

| Question | Answer |
|----------|--------|
| Is data encrypted in transit? | **Yes** (all network calls use HTTPS/TLS) |
| Is data encrypted at rest (on device)? | **Yes** — AES via Hive + keystore-held key |
| Can users request data deletion? | **Yes** — in-app "Reset app" wipes everything; plus a web/email deletion request path |
| Committed to Play Families policy? | Not directed at children |
| Independent security review? | Optional — declare only if actually done |

**Section B — Data types** (Collected = transmitted off device; Shared =
transferred to a third party by the developer)

| Data type | Collected? | Shared? | Processed on-device / ephemeral | Required/Optional | Purpose |
|-----------|-----------|---------|-------------------------------|-------------------|---------|
| Messages — SMS/verification codes | **No** (processed on device; not sent to us) | **No** | Yes — classified in memory | Required (permission) | App functionality (detect & route your codes) |
| Contacts | **No** (accessed on device for the picker) | **No** | Yes | Optional | App functionality (choose recipients) |
| App activity — forward history | **No**, unless cloud sync is ON → then **Yes (optional, redacted)** | **No** | On device by default | Optional | App functionality |
| Financial info — amounts parsed from codes | **No** (extracted on device) | **No** | Yes | Required | App functionality (risk gating) |
| Purchases — subscription | Handled by **Play Billing / Razorpay** (declare "Purchase history" as collected by the processor) | **No** | n/a | Optional | App functionality (Premium) |
| App info & performance — crash logs | **Yes** *only if* Crashlytics/Sentry is added | **No** | n/a | Optional | Analytics / stability |
| Device or other IDs | Prefer **No** — avoid unless analytics requires it | **No** | n/a | Optional | Analytics |

- **No data is sold.** Answer "No" to any sale/advertising-sharing question.
- **Nuance to verify against current policy:** requesting the SMS permission
  triggers extra scrutiny even though you don't *collect* the content off-device.
  Keep the on-device claim literally true (audit that no code is logged or sent),
  and be ready to show it in the Permissions Declaration + demo video.

---

## 6. Content rating (IARC questionnaire)

Category: **Tools / Utility**. Expected result: **Everyone (Google) / PEGI 3**.

Guidance for the questionnaire answers:

- Violence, sexual content, profanity, controlled substances, gambling: **No** to all.
- User-generated content shared with other users / publicly: **No** (forwarding
  is to user-chosen recipients, not open/social sharing).
- Does the app let users interact or exchange content? **No** open communication
  feature — answer per the questionnaire's exact wording (private, user-initiated
  forwarding only).
- Shares user's location: **No**.
- **Digital purchases: Yes** — the app sells a subscription (this adds an "In-app
  purchases" note but does not raise the age rating).
- Personal/sensitive data handling: answer honestly per the Data Safety form.

Result should land at **Everyone / PEGI 3** with an "In-app purchases" badge.
Re-run the questionnaire whenever functionality materially changes.

---

## 7. Privacy Policy checklist (required for an SMS-permission app)

Publish at a public HTTPS URL and link it in Play Console **and** in-app. Must
contain:

- [ ] Effective date + last-updated date; how changes are communicated.
- [ ] Developer/legal entity identity + contact email.
- [ ] **Prominent disclosure of SMS access** — what is accessed, why, and that it
      is used *only* to detect and route the codes the user configured. (Play's
      SMS/Call-Log policy requires this specific disclosure.)
- [ ] **On-device processing statement** — codes are classified locally and are
      not transmitted to the developer's servers.
- [ ] Exactly what data is collected vs. only processed on-device (mirror the
      Data Safety table): SMS content (on-device), contacts (on-device),
      history (local; redacted if synced), purchase records, optional crash logs.
- [ ] What is **not** collected/sold, and that codes are never sold.
- [ ] Third parties / processors named (e.g., Razorpay/Play Billing, and any
      crash/analytics SDK) with links to their policies.
- [ ] Data retention periods and the **deletion path** (in-app Reset + email/web
      request), with a response SLA.
- [ ] Security measures (AES at rest, TLS in transit, keystore, app lock).
- [ ] Children: not directed to children under 13; no knowing collection.
- [ ] User rights (access, deletion) and how to exercise them; region notes
      (India DPDP / GDPR-style requests) if applicable.
- [ ] User responsibility: forward only codes you are entitled to share.

## 8. Terms of Service checklist

- [ ] Acceptance of terms; eligibility/minimum age.
- [ ] Description of the service (rule-based forwarding of the user's own codes).
- [ ] **Acceptable use** — lawful use only; user is responsible for having the
      right/consent to forward the codes and to message the recipients; **no use
      to read or intercept other people's messages**; no fraud.
- [ ] Account terms (if accounts exist) and security responsibilities.
- [ ] **Subscription & billing** — Premium ₹99/month, auto-renewal, how to
      cancel, refunds governed by Play/App Store policy, price-change notice.
- [ ] Disclaimers — SMS delivery is not guaranteed; carrier charges may apply to
      forwards sent over the device SIM; service provided "as is."
- [ ] Limitation of liability; indemnity for misuse.
- [ ] Suspension/termination; effect of termination.
- [ ] Changes to terms; governing law & jurisdiction; dispute resolution.
- [ ] Contact information.

---

## 9. Versioning strategy

- **Format:** `versionName = MAJOR.MINOR.PATCH`, `versionCode = monotonic
  integer` — in `pubspec.yaml` this is `version: 1.1.0+2` (name `1.1.0`, code
  `2`). Current baseline.
- **Semver rules:** MAJOR = breaking/behavioral shifts (e.g. the SMS-capture
  pivot, paid-tier restructuring); MINOR = new user-facing features
  (channels, categories); PATCH = fixes/polish, no new capability.
- **versionCode:** must strictly increase on **every** upload to any track (Play
  rejects a re-used code). Simplest rule: bump the `+N` build number on each
  build regardless of the name; never reuse.
- **Rebrand note:** if you also change `applicationId`
  (`com.otpbridge.otpbridge` → e.g. `com.keyward.app`), that is a **new Play
  listing**, not an update — plan a fresh package + data migration story, since
  users can't in-place upgrade across a package-name change.
- Tag each release in VCS (`v1.2.0`) and keep [`CHANGELOG.md`](../CHANGELOG.md)
  in lockstep.

## 10. Release checklist (tracks + staged rollout)

**Pre-flight (every release)**
- [ ] `flutter analyze` clean; `flutter test` green.
- [ ] `flutter build appbundle --release` succeeds; release signing configured,
      keystore backed up.
- [ ] No `print`/logging of code contents anywhere (grep the diff).
- [ ] Offline queue + reboot behavior re-verified on a physical device.
- [ ] `versionCode` bumped; CHANGELOG + tag updated.
- [ ] Data Safety, content rating, privacy URL, and (if needed) Permissions
      Declaration + demo video current.

**Track progression**
1. **Internal testing** — up to 100 trusted testers; smoke-test the full flow;
   review the automated **pre-launch report** (crashes, accessibility, policy
   warnings).
2. **Closed testing (alpha)** — a controlled group; validate on real hardware,
   permissions prompts, billing (real Razorpay/Play Billing), and dark mode.
3. **Open testing (beta)** — public opt-in; watch crash-free rate, ANRs, reviews;
   this is where a permission-declaration app gathers evidence for review.
4. **Production — staged rollout:** 10% → 25% → 50% → 100%, advancing only when
   crash-free sessions and vitals hold at each step.

**Halt/rollback criteria:** pause or halt the rollout if crash-free sessions drop
below your gate (e.g. <99.0%), ANR rate spikes, a policy warning appears, or
billing/permission errors surface. Fix, bump versionCode, resubmit.

**iOS companion (parallel):** positioned strictly as a companion (rules /
recipients / history / approvals / notifications — **no SMS-reading claims**);
privacy nutrition labels + `NSFaceIDUsageDescription` set; TestFlight → App Store
review → phased release.
