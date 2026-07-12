# Branding — Rebrand & Brand Direction

> Positioning guardrail (from [`FEASIBILITY.md`](FEASIBILITY.md)): the brand must
> read as **secure verification / authentication assistance / trusted
> device-to-device access** — a tool that helps *you* route *your own*
> verification codes to people *you* trust, processed on-device. It must **never**
> imply "read other people's SMS," surveillance, interception, or bypassing an
> app's login. Every name, tagline, and visual below is chosen against that line.

Working name today: **OTPBridge** (`applicationId com.otpbridge.otpbridge`,
`version 1.1.0+2`). The "OTP" prefix is technically accurate but skews generic
and slightly toward the "reading codes" framing we want to soften. The rebrand
moves the emphasis to *verification*, *keys/trust*, and the *bridge/relay*
metaphor of moving a code from A to B with consent.

---

## 1. Name candidates

Availability notes are **generic guidance** — I can't check live registries.
Rule of thumb applied: coined/invented words score best for trademark
defensibility and exact-match `.com`; descriptive compounds (Trust-, Key-,
Guard- + common noun) are usually taken as `.com` and crowded at the trademark
office, especially in fintech/security classes. Always run a live check on
(a) exact `.com`, (b) Google Play developer-name + listing-title collision,
(c) a USPTO/registry knockout search in Nice classes 9/42 (software/SaaS)
before committing, plus a quick app-store search on iOS.

### Guard / protect family

| Name | One-line rationale | Availability risk |
|------|--------------------|-------------------|
| **Keyward** | "key" + "ward" (to guard) — guards the access keys you route. Coined, premium, short. | **Low–Med.** Invented word; exact `.com` may be parked but obtainable; Play title likely clear. Strong TM. |
| **Codeward** | Parallel to Keyward — "guards your codes." Says OTP without saying OTP. | **Med.** Coined but more literal; check for security-tool collisions. |
| **Guardcode** | Descriptive, instantly legible "guards your codes." | **Med–High.** Common compound; `.com` likely taken, crowded TM. |
| **Sentro** | From sentry/sentinel — a quiet guardian. Soft, modern, short. | **Med.** Short coined names are often domainer-parked; verify TM. |
| **Aegis Verify** | Aegis = the mythic protective shield; adds instant "trust." | **High** if used bare — "Aegis" is heavily used in security. Needs the qualifier + TM search. |

### Verify / attest family

| Name | One-line rationale | Availability risk |
|------|--------------------|-------------------|
| **Verixa** | Coined from "verify," fintech-grade, distinctive x-ending. | **Low–Med.** Invented; good `.com`/TM odds. |
| **Verica** | Softer coined "verify" — approachable, trustworthy. | **Med–High.** Collides with an existing security company "Verica." |
| **Attesta** | From "attest" (to verify/witness) — elegant, premium, defensible. | **Low.** Rare coined stem; strong `.com`/TM odds. |
| **Verifly** | "verify" + "fly" (fast). | **High.** Collides with the "VeriFLY" travel-verification app — likely blocked. Listed only to rule out. |
| **Credence** | Real word meaning "trust/belief" — pure trust play. | **Med–High.** Dictionary word; `.com` almost certainly taken, TM crowded. Premium but risky. |

### Relay / bridge family (retains OTPBridge heritage)

| Name | One-line rationale | Availability risk |
|------|--------------------|-------------------|
| **Trustbridge** | Keeps the "bridge" equity; foregrounds trust; matches the "trusted device-to-device" line in the README. | **Med–High.** Common compound; `.com` likely taken, TM crowded in fintech — qualify or add a coined twist. |
| **Keybridge** | "key" + "bridge" — bridges your access keys between devices/people. | **Med–High.** Descriptive; several existing "KeyBridge" marks. |
| **Keyrelay** | Clear "relay of keys" — nails the device-to-device handoff. | **Med.** Descriptive-coined; check `.com`, likely obtainable as `.app`. |
| **Passrelay** | Relays passcodes to the right person, on your terms. | **Med.** Descriptive; verify `.com`. |
| **Relayn** | "relay" clipped — punchy, app-store-friendly, coined. | **Med.** Short coined; domainer risk. |

### Abstract / premium family

| Name | One-line rationale | Availability rating |
|------|--------------------|---------------------|
| **Cipherly** | "cipher" + "-ly" — encryption-forward, calm SaaS tone. | **Low–Med.** Coined; decent `.com`/TM odds. |
| **Nexopass** | "nexus" + "pass" — connected passcodes across your circle. | **Med.** Coined-ish; verify collisions. |
| **Vouchr** | "vouch" (to verify/stand for) with a trendy dropped vowel. | **Med–High.** "vouch" is common; crowded, but `.app`/handles may exist. |
| **Attest** (bare) | Ultra-clean single word. | **High.** Dictionary word; taken as `.com` and TM. Use only as a stem (see Attesta). |

That's 20 candidates spanning four naming territories.

### Top 3 recommendation

1. **Keyward** — *lead pick.* Coined, short, premium, and trademark-defensible.
   It carries the exact promise ("guards the keys you route") without touching
   the "reads your SMS" third rail, works as a clean wordmark and a
   shield/key icon, and reads as a product, not a utility. Best long-term
   equity and cleanest legal path.
2. **Verixa** — *safest distinctiveness.* Invented from "verify," fintech-grade,
   low collision risk on both `.com` and trademark. Excellent if you want the
   category ("verification") legible in the name while staying ownable. Slightly
   more abstract than Keyward, so pair with a descriptive subtitle in the store.
3. **Trustbridge** — *heritage + instant legibility.* Retains the "Bridge"
   equity already in the codebase, docs, and package id, and states the trust
   promise outright. The trade-off is real: higher `.com`/trademark risk as a
   common compound. Recommend only after a knockout search; if it's blocked,
   fall back to a coined bridge variant (**Keyrelay** / **Relayn**).

Strong runners-up worth a live check: **Attesta** (most premium/defensible) and
**Cipherly** (best "encryption-first" tone).

> The store listing in [`STORE_LISTING.md`](STORE_LISTING.md) is written with
> **Keyward** as the working brand; every title/short-description block also
> lists Verixa and Trustbridge variants so the choice stays reversible.

---

## 2. Brand direction — visual identity

### 2.1 Color palette

Built directly on the shipped design tokens (`lib/core/theme/app_colors.dart`):
indigo primary + slate neutrals, "restrained, trust-first, no flashy gradients."
Keep this — it already reads fintech-grade. The rebrand only *formalizes* it and
adds two disciplined accents.

**Brand core**

| Token | Hex | Use |
|-------|-----|-----|
| Indigo 500 (Primary) | `#4F46E5` | Primary actions, brand mark, links, active states |
| Indigo 600 (Press) | `#4338CA` | Pressed/hover, gradientable deep end |
| Indigo 400 (Accent) | `#818CF8` | Dark-theme primary, highlights, focus rings |
| Indigo 100 (Subtle) | `#E0E7FF` | Primary-subtle fills, chips, selection wash |
| Indigo 950 (Ink) | `#1E1B4B` | Deep brand ink, logo on light, marketing headers |

**Neutrals (slate ramp)** — `#FCFDFE #F8FAFC #F1F5F9 #E2E8F0 #CBD5E1 #94A3B8
#64748B #475569 #334155 #1E293B #0F172A #080D1A` (slate 25→950). Text: primary
`#0F172A`, secondary `#475569`, tertiary `#94A3B8`.

**Functional (semantic)**

| Role | Light | Dark |
|------|-------|------|
| Success (delivered/verified) | `#059669` | `#34D399` |
| Warning (pending/approval) | `#D97706` | `#FBBF24` |
| Danger (blocked/high-risk) | `#DC2626` | `#F87171` |
| Info (assistant/tips) | `#0284C7` | `#38BDF8` |

**Two new brand accents** (use sparingly — icon glints, premium/paywall):

| Token | Hex | Use |
|-------|-----|-----|
| Signal Cyan | `#22D3EE` | The "spark"/verify glint in the icon; premium accent |
| Trust Teal | `#0D9488` | Secondary badge for "secure/on-device"; pairs with indigo without competing |

**Light + dark note.** Light theme: `#FCFDFE`/`#F8FAFC` backgrounds, indigo 500
primary, ink `#0F172A`. Dark theme (already defined): background `#0B1120`,
surface `#111A2E`, raised `#16203A`, and primary steps up to **indigo 400
(`#818CF8`)** for contrast on dark — never use indigo 600 as the primary on
dark. Maintain ≥4.5:1 body-text contrast in both. Glass surfaces use the shipped
`glassFill`/`glassBorder` tokens (light `#CCFFFFFF`/`#14000000`, dark
`#14FFFFFF`/`#1FFFFFFF`).

### 2.2 Typography

**Keep the current stack** — it's already correct for a trust-first product.

- **Inter** — all UI and marketing text (weights 400/500/600/700). Set tight
  tracking on display sizes, normal on body. Wordmark can be Inter SemiBold with
  −2% letter-spacing, or a lightly customized Inter for a bespoke mark.
- **JetBrains Mono** — reserved for the things that must read as *precise and
  tamper-evident*: OTP codes, amounts, timestamps, rule IDs (already wired via
  `MonoText.otp` / `MonoText.amount`, tabular figures). Use it in marketing too —
  a masked code like `••• 4821` in JetBrains Mono is an instant brand signal.

Evolution (optional, not required): if you want a more ownable wordmark later,
commission a custom-drawn logotype based on Inter's skeleton — keep the running
UI on Inter. Do not introduce a third typeface.

### 2.3 Logo / icon concepts

Four distinct directions, described tightly enough to hand to a designer or an
icon generator. All should render legibly at 48dp, use indigo `#4F46E5` as the
core with a single accent glint, and ship as an Android **adaptive icon**
(separate foreground + background layers, safe zone respected). Existing
`docs/store_icon_512.png` / `store_icon_1024.png` can be the baseline to iterate
from.

1. **Shield + forward-arrow ("guarded handoff").**
   A rounded shield silhouette in indigo; inside, a single clean chevron/arrow
   pointing right (the "forward"), or a keyhole with a small arrow tail. Optional
   Signal Cyan (`#22D3EE`) glint at the arrow tip. *Connotes:* protection +
   intentional, directional forwarding. Safest, most literal to "secure
   verification relay." Recommended default for **Keyward**.

2. **Bridge glyph ("the span").**
   A minimal two-pier suspension-bridge arc, or two rounded nodes joined by a
   short indigo span with a small dot/spark traveling across it. *Connotes:*
   trusted device-to-device connection; directly retains OTPBridge/Trustbridge
   heritage. Best if the final name keeps "bridge/relay." Reads well as a
   monoline mark.

3. **Keyhole + spark ("the verified key").**
   A geometric keyhole (circle over a slot) with a four-point spark/star at its
   center or emerging from the slot. Indigo body, cyan spark. *Connotes:*
   access, authentication, the moment a code "clicks." Ideal for **Keyward** /
   **Keybridge** — the "key" is literal.

4. **Enclosed check / node-relay ("verified & routed").**
   A rounded-square node containing a checkmark that doubles as a routing path —
   the check's long stroke extends into an arrow or a second smaller node.
   *Connotes:* verification confirmed + delivered to the right place. Clean,
   modern, scales tiny; pairs naturally with **Verixa / Attesta** (verify
   family).

For any direction: build the adaptive icon so the background layer is a flat
indigo→indigo-600 or slate field, and the foreground is the single mark with
comfortable padding; avoid text in the icon; test on light *and* dark launchers.

---

## 3. Voice & tagline

### Taglines (5 options)

1. **"Your codes. Your rules. Delivered."** — control + the forwarding promise.
2. **"Verification, routed with trust."** — category-clear, calm.
3. **"The right code to the right person — on your terms."** — describes the
   selective, consent-first behavior without over-claiming.
4. **"Private by design. On your device."** — leads with the privacy proof point.
5. **"Never miss the code that matters."** — benefit-first, human.

Primary recommendation: **#1** for the store title area, **#4** as the privacy
sub-line on the feature graphic.

### Brand voice

Calm, precise, and quietly confident — the tone of a well-built security tool,
not a growth-hacked app. We explain *what happens to your data* before we sell a
feature, and we never over-promise. Sentences are short and concrete; we favor
plain verbs ("forward," "approve," "encrypt") over jargon and avoid hype words
("magic," "revolutionary," "instant") and fear-based selling. We're honest about
limits (on-device processing, user consent, banking codes held for approval) —
that honesty *is* the brand. When in doubt, sound like a trustworthy colleague
handing you your keys, not a marketer.
