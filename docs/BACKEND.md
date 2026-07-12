# OTPBridge — Backend Architecture, Schema & API Contracts

The app is **offline-first**; the backend is an optional mirror for multi-device
sync, iOS-companion delivery, subscription verification, and analytics. Default
recommendation: **Supabase** (Postgres + Auth + Realtime + Edge Functions +
Storage), chosen because the local model layer already serializes to JSON that
maps cleanly to these tables. Firebase is a drop-in alternative (Firestore +
Auth + Functions + FCM).

> **Privacy rule:** never store raw OTP bodies server-side. Sync rules,
> recipients, and *redacted* history only (OTP digits masked, body dropped).

## Entity → table map

| Local model | Table | Synced? |
|-------------|-------|---------|
| `Recipient` / `RecipientGroup` | `recipients` / `recipient_groups` | ✅ |
| `ForwardRule` | `rules` | ✅ |
| `HistoryEntry` | `history` | ✅ redacted |
| `ForwardTask` | `forward_tasks` | optional (for cross-device delivery) |
| `AppSettings` | `user_settings` | ✅ (non-secret) |
| `SubscriptionState` | `subscriptions` | ✅ server-authoritative |
| `AiSuggestion` | `suggestions` | server-generated (optional) |

## Postgres schema (Supabase)

```sql
-- Users are provided by Supabase Auth (auth.users). All tables are
-- row-level-secured to auth.uid().

create table devices (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  platform      text not null check (platform in ('android','ios')),
  role          text not null default 'sender'  -- 'sender' | 'companion'
                  check (role in ('sender','companion')),
  fcm_token     text,
  last_seen_at  timestamptz default now(),
  created_at    timestamptz default now()
);

create table recipients (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  phone         text not null,
  email         text,
  channel       text not null default 'sms',
  group_ids     text[] default '{}',
  updated_at    timestamptz default now()
);

create table recipient_groups (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  updated_at    timestamptz default now()
);

create table rules (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  enabled       boolean not null default true,
  sort_order    int not null default 0,
  payload       jsonb not null,   -- full ForwardRule.toJson (categories,
                                  -- brands, senders, keywords, schedule,
                                  -- max_amount, action, recipient_ids...)
  times_triggered int not null default 0,
  updated_at    timestamptz default now()
);

create table history (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  at            timestamptz not null,
  category      text not null,
  brand         text,
  amount        numeric,
  otp_masked    text,             -- e.g. '••••12' — NEVER the full code
  outcome       text not null,
  rule_id       uuid,
  rule_name     text,
  recipient_names text[] default '{}',
  detail        text
);

create table subscriptions (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  tier          text not null default 'free' check (tier in ('free','premium')),
  forwards_used int not null default 0,
  period_start  date not null,
  expires_at    timestamptz,
  provider      text,             -- 'play' | 'appstore' | 'razorpay'
  provider_ref  text,
  updated_at    timestamptz default now()
);

create table user_settings (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  payload       jsonb not null,   -- non-secret AppSettings fields
  updated_at    timestamptz default now()
);

-- RLS (apply to every table)
alter table rules enable row level security;
create policy "own rows" on rules
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
-- …repeat per table.
```

## API contracts (REST / Edge Functions)

Base: `https://<project>.supabase.co`. Auth: `Authorization: Bearer <jwt>`.
CRUD tables use PostgREST directly; the non-trivial operations are functions.

### `POST /functions/v1/sync`
Two-way delta sync. Client sends locally-changed rows since `since`; server
returns rows changed server-side since the same cursor. Last-write-wins on
`updated_at`.
```jsonc
// Request
{ "since": "2026-07-12T09:00:00Z",
  "rules": [ { "id": "…", "payload": { … }, "updated_at": "…" } ],
  "recipients": [ … ],
  "history": [ { "id":"…","otp_masked":"••••12", … } ],   // redacted
  "settings": { … } }
// Response
{ "server_time": "2026-07-12T09:05:00Z",
  "rules": [ … ], "recipients": [ … ], "deleted": { "rules": ["id1"] } }
```

### `POST /functions/v1/forward-relay`  (cross-device / companion delivery)
When the Android sender can't send directly (e.g. deliver to an iOS companion or
via WhatsApp/Email server-side), it posts a relay request.
```jsonc
// Request
{ "recipient_id": "…", "channel": "push|email|whatsapp",
  "brand": "Amazon", "category": "ecommerce",
  "otp": "563412",            // transient; not persisted
  "amount": null, "idempotency_key": "task-uuid" }
// Response
{ "status": "sent|queued|failed", "message_id": "…" }
```
The function is idempotent on `idempotency_key`; the OTP is used to compose the
message and then discarded (never written to a table or log).

### `POST /functions/v1/verify-purchase`
Validates a Play/App Store/Razorpay receipt and updates `subscriptions`
server-authoritatively; returns the canonical `SubscriptionState`.
```jsonc
// Request
{ "provider": "play", "purchase_token": "…", "product_id": "premium_monthly" }
// Response
{ "tier": "premium", "expires_at": "2026-08-12T00:00:00Z" }
```

### `POST /functions/v1/suggestions/generate`  (optional, server AI)
Runs pattern analysis over redacted history and returns proposed rules
(`AiSuggestion.proposedRule` JSON). Can also run fully on-device.

## Realtime & push

- **Realtime:** subscribe to `rules`, `recipients`, `subscriptions` changes for
  instant multi-device updates (Supabase Realtime channel per `user_id`).
- **Push:** FCM (Android) / APNs (iOS) tokens live in `devices.fcm_token`.
  Companion delivery and "approval needed on another device" use push.

## Client integration seam

Add `lib/data/remote/remote_sync_service.dart` implementing a `RemoteSync`
contract (pull/push/subscribe). Wire it as a provider and call it from a
background sync trigger. No repository, engine, or feature code changes —
repositories remain the source of truth; sync reconciles them.
