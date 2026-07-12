# OTPBridge — Testing Strategy

## Layers

| Layer | What | Where |
|-------|------|-------|
| **Unit** | Classification (OTP/amount extraction, brand+category, confidence), rule engine (matching, schedules, escalation), forwarding queue (fan-out, backoff, dedupe, delivery states) | `test/classification`, `test/rules`, `test/queue` |
| **Pipeline** | End-to-end `SmsPipeline.process` with fakes: forward, block, approval, dedupe, subscription cap | `test/pipeline` |
| **Widget** | Key screens render, empty states, dark mode, a rule-editor save flow | `test/widget` (add as needed) |
| **Integration** | On-device: SMS receive → forward → history; queue retry under airplane mode | manual + `integration_test/` (optional) |

## Running

```bash
flutter test                     # all unit + pipeline + widget tests
flutter test test/rules          # a single suite
flutter test --coverage          # lcov → coverage/lcov.info
```

## Determinism rules

- All engines take an injected `clock` (`DateTime Function()`) and `Uuid` — never
  read wall-clock/random directly in logic under test.
- The queue is driven by calling `processDue()` explicitly in tests — no real
  `Timer`s, no `await Future.delayed`.
- Repositories have in-memory fakes; `LocalStore.openForTest(path)` opens
  unencrypted Hive boxes for storage-touching tests.
- `NoopNotificationService` (shipped in the domain layer) stands in for
  notifications.

## Coverage focus (highest-risk logic)

1. **OTP extraction false-positives** — reference numbers, masked account
   numbers, amounts, and phone numbers must NOT be treated as OTPs.
2. **Financial escalation** — banking/UPI/card OTPs above caps must require
   approval, never silently forward.
3. **Rule ordering** — first-match-wins; disabled rules skipped.
4. **Queue safety** — one failing task never stalls the batch; no double-send;
   backoff grows; terminal after `maxAttempts`.
5. **Dedupe** — the same message within a minute is processed once.

## What ships in this build

- `test/classification/` — extractor + engine tests
- `test/rules/` — schedule evaluator + rule engine (40 tests)
- `test/queue/` — forwarding queue (14 tests)
- `test/pipeline/` — end-to-end pipeline tests

Add widget/integration tests before a public release; the unit suite already
guards the security-critical paths.
