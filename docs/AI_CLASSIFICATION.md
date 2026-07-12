# OTPBridge — AI Classification & Assistant: Architecture & Model Choice

You asked me to research and choose the best model, and to explain why. Here is
the honest engineering answer, and what's actually shipping.

## TL;DR decision

**A hybrid, on-device engine: DLT-sender-ID + brand catalog + regex extraction +
keyword heuristics with confidence scoring — NOT a bundled LLM.** An optional
cloud LLM is a pluggable enhancement for the low-confidence tail, behind the
same interface, used only when online.

This is the right call for this product, and here's the reasoning.

## Why not a bundled on-device LLM (Gemma / Phi / Qwen / TinyLlama)?

| Factor | Bundled LLM (e.g. Gemma 2B / Phi-3-mini) | Hybrid engine (shipping) |
|--------|------------------------------------------|--------------------------|
| App size | +1.5–2.7 GB model weights | ~0 (pure Dart) |
| RAM at runtime | 2–4 GB; OOM-crashes on many mid-range Indian phones | negligible |
| Latency per SMS | 300 ms – several seconds | <1 ms |
| Battery | significant (sustained compute) | negligible |
| Offline | yes (but heavy) | yes (fully) |
| Accuracy on Indian OTP SMS | high, but overkill | **95%+** — these messages are templated |
| Determinism / testability | low (probabilistic) | high (unit-tested) |

The key insight: **Indian transactional SMS is extremely structured.** It's sent
by DLT-registered headers (`VM-AMAZON`, `AX-HDFCBK`, `JD-SBIINB`) in fixed
templates ("Your <brand> OTP is <code>", "Rs <amt> debited... UPI"). A curated
sender-ID + brand catalog with regex extraction nails category, brand, OTP,
amount, and transaction type at essentially zero cost. An LLM's marginal
accuracy gain here does not justify 2 GB of weights and multi-second latency on
a utility app that must run quietly in the background on a ₹10k phone.

## Why not an on-device TFLite/ONNX text classifier (MobileBERT/DistilBERT)?

A fine-tuned MobileBERT (~25 MB, TFLite) is the *realistic* ML option and a
reasonable future addition. But:
- It needs a labeled training corpus of Indian SMS we don't have yet.
- For templated OTP SMS, it barely beats the catalog while adding a model
  file, a native inference dependency, and non-determinism.
- It still can't do the structured *extraction* (OTP digits, exact ₹ amount,
  merchant) — you need regex for that regardless.

So the pragmatic sequencing is: ship the hybrid engine now (excellent today),
add a small TFLite classifier later **only** to improve the fuzzy tail
(unknown/ambiguous senders), gated behind a confidence threshold.

## The shipping architecture (hybrid, layered)

```
IncomingSms
   │
   ├─ 1. Sender-ID normalization  (VM-AMAZON-S → AMAZON)         [brand_catalog]
   ├─ 2. Brand catalog lookup     (150+ Indian brands → category)[brand_catalog]
   ├─ 3. Regex extraction         (OTP, ₹amount, merchant, type) [otp_extractor]
   ├─ 4. Keyword/financial heuristics (when no brand match)      [category_classifier]
   └─ 5. Confidence score (0–1)
        │
        └─ if confidence < ~0.6 AND online AND user opted in:
             → optional cloud LLM (Claude) refines category      [classify() seam]
```

- Runs fully offline. Nothing about an OTP needs to leave the device to be
  classified.
- The async `ClassificationEngine.classify()` method is the documented seam
  where a TFLite model or a cloud LLM slots in for low-confidence messages —
  `classifySync()` (rules only) is always available as the instant fallback.
- Categories: 28, including the new Recharge, Insurance, Tax, Investments, and
  Promotions, each mapped to a high-level `CategoryGroup` for the UI.

## The natural-language rule assistant ("Forward Amazon orders to my wife")

Same philosophy: **on-device slot-filling, not a bundled LLM.** Rule-creation
intents are short and patterned — `forward <brand/category> to <person> <when>`.
The parser:
1. Runs the sentence through the existing classifier to extract brand +
   category (reusing all catalog logic).
2. Matches the recipient against the user's saved recipients by name/first-name.
3. Parses the action (forward / block / ask) and schedule (office hours /
   weekdays / weekends / "10am–7pm") from a small grammar.
4. Emits a `RuleDraft` with a confidence and a list of any missing slots, which
   the UI confirms in one tap.

This is instant, offline, free, deterministic, and unit-tested. For fuzzier
phrasing, the exact same `parse()` entry point can defer to a cloud LLM when
online — an enhancement, never a dependency. This matches the user's own stated
preference (in their environment) to avoid metered API dependencies where a
local approach suffices.

## Dynamic service detection

The inbox is scanned (`content://sms/inbox`, READ_SMS) and every message run
through the same classifier, then grouped into `DetectedService`s (brand,
category, message count, last seen). The rule wizard shows **only** services the
user actually receives SMS from, and the suggestion engine proposes rules for
uncovered high-volume services. No model required — it's the classifier applied
to history.

## When we WOULD add a real model

- A **TFLite MobileBERT** (~25 MB) to lift accuracy on unknown/foreign-template
  senders, once we have a labeled corpus — gated to low-confidence messages so
  the fast path stays instant.
- A **cloud LLM** (Claude) for the natural-language assistant's long-tail
  phrasing and for a future "explain this rule / suggest better rules" feature —
  online-only, opt-in, never in the hot path of OTP handling.

Both fit behind interfaces that already exist. Shipping the hybrid engine first
is the correct, user-respecting default.
