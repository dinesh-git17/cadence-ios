---
name: cadence-supabase
description: >
  Authoritative reference for all Supabase integration work in the Cadence iOS app.
  Read this skill before writing any code that touches SupabaseClient, Auth, database
  queries, Realtime subscriptions, or RLS-governed tables. Applies to every Swift file
  in the project that imports Supabase.
---

# Cadence — Supabase Integration Skill

You are working on **Cadence**, a SwiftUI iOS app backed by Supabase. This skill is the
single source of truth for how Supabase is used in this codebase. Follow it exactly.
Do not invent patterns, do not use API shapes from memory — verify against the references.

---

## Reference Files — Load Before Coding

| File                            | Load when...                                              |
| ------------------------------- | --------------------------------------------------------- |
| `references/client-setup.md`   | Setting up SupabaseClient singleton, SPM dependency       |
| `references/models.md`         | Implementing or modifying any Codable model struct        |
| `references/auth.md`           | Apple Sign In, email auth, session state, sign out        |
| `references/queries.md`        | Writing any PostgREST query (insert, fetch, update, upsert) |
| `references/realtime.md`       | Subscribing to Realtime changes on shared_logs            |
| `references/error-handling.md` | Defining or mapping errors, ViewModel error patterns      |
| `references/env-config.md`     | xcconfig setup, Info.plist wiring, multi-environment      |

Always load the relevant reference file(s) before writing implementation code.
Never write query patterns, model structs, or auth flows from memory.

---

## Non-Negotiable Rules

Read these before touching any Supabase code. They are not suggestions.

1. **Never hardcode credentials.** The Supabase URL and anon key must come from
   `Bundle.main.infoDictionary` via xcconfig. See `references/env-config.md`.

2. **Never query `cycle_logs` from a partner session.** RLS physically prevents it, but
   you must not write queries that attempt it. Partners read `shared_logs` only.

3. **Encrypted fields are opaque `String` ciphertext in model structs.** Never decode
   an encrypted field directly into a domain type. Decrypt via `CadenceCrypto` after fetch.
   See `references/models.md`.

4. **Clean up every Realtime channel.** Every `supabase.channel(...)` call must have a
   corresponding `await supabase.removeChannel(channel)` in `.onDisappear` or `deinit`.
   Leaking channels causes memory and connection problems. See `references/realtime.md`.

5. **All Supabase calls are async throws.** Wrap them in `do / catch` and map to
   `CadenceSupabaseError`. Never use `try?` on a Supabase call except in teardown paths.
   See `references/error-handling.md`.

6. **Use `upsert` for `shared_logs`, not insert.** A tracker updating sharing settings
   re-writes the same row for a given `(tracker_user_id, log_date)`. Use `upsert` with
   `onConflict:` to avoid duplicate-key errors.

7. **Always call `.execute()` to terminate a query builder.** The PostgREST builder is
   lazy. A builder without `.execute()` or `.single()` does nothing.

---

## Row Level Security — Awareness and Query Constraints

RLS is enforced at the Supabase (PostgreSQL) layer. A session that attempts to read
a table it has no policy for receives an empty result or a `406 Not Acceptable` error,
not a permission error. Do not rely on RLS errors for user-facing logic — enforce
intent in your query patterns instead.

### Table Policies

| Table | Read | Write | Notes |
|---|---|---|---|
| `users` | Owner only | Owner only | Handled via Auth UID match |
| `cycle_profiles` | Owner only | Owner only | Tracker's own data |
| `cycle_logs` | Owner only | Owner only | **Partners can never read this table** |
| `sharing_settings` | Owner + connected partner | Tracker (owner) only | Partner reads to show tracker's sharing state |
| `partner_connections` | Both users in the connection | Both (for status updates) | |
| `invite_links` | Creating tracker only | Creating tracker only | |
| `shared_logs` | Partner (partner_user_id match) | Tracker (tracker_user_id match) only | The only table partners read for health data |

### Critical Access Boundary

```
cycle_logs    <- tracker session only. NEVER query from partner session.
shared_logs   <- partner reads. Tracker writes. This is the data-sharing contract.
```

Any view or service that fetches health data for the partner card **must** use
`shared_logs`, not `cycle_logs`. RLS will prevent the query from working, but the
code intent must be correct regardless.

---

## Model Quick Reference

See `references/models.md` for full struct definitions with CodingKeys.

| Model | Table | Key fields |
|---|---|---|
| `CadenceUser` | `users` | id, email, displayName, isTracker |
| `CycleProfile` | `cycle_profiles` | userId, lastPeriodDate, seededCycleLength, seededPeriodDuration |
| `CycleLog` | `cycle_logs` | id, userId, logDate + encrypted fields (periodFlow, mood, energy, symptoms, sleepQuality, intimacyLogged, intimacyProtected, notes) |
| `InsertCycleLog` | `cycle_logs` (insert) | Same fields as CycleLog, Encodable only |
| `SharingSettings` | `sharing_settings` | userId, sharePeriod, shareSymptoms, shareMood, shareEnergy |
| `PartnerConnection` | `partner_connections` | id, trackerUserId, partnerUserId, status |
| `InviteLink` | `invite_links` | id, trackerUserId, token, expiresAt, used |
| `SharedLog` | `shared_logs` | id, trackerUserId, partnerUserId, logDate + encrypted fields + cycleDay, cyclePhase, predictedNextPeriod |
| `UpsertSharedLog` | `shared_logs` (upsert) | Same fields as SharedLog, Encodable only |

---

## Query Pattern Summary

See `references/queries.md` for full implementations.

| Operation | Service | Table | Key detail |
|---|---|---|---|
| Insert cycle log | `CycleLogService` | `cycle_logs` | Caller encrypts before calling |
| Fetch today's log | `CycleLogService` | `cycle_logs` | Date range filter with ISO8601 |
| Fetch partner shared log | `PartnerService` | `shared_logs` | Filter by partner_user_id |
| Update sharing settings | `SharingService` | `sharing_settings` | Must re-write shared_logs after |
| Create invite link | `PartnerService` | `invite_links` | 7-day expiry, UUID token |
| Validate invite token | `PartnerService` | `invite_links` | Check used=false + not expired |
| Accept invite | `PartnerService` | `invite_links` + `partner_connections` | Two-step: mark used, create connection |
| Upsert shared log | `SharingService` | `shared_logs` | `onConflict: "tracker_user_id,log_date"` |

---

## Auth Summary

See `references/auth.md` for full implementations.

- **Session state** is managed by `AuthViewModel` using `supabase.auth.authStateChanges`.
- **Apple Sign In** uses PKCE flow: raw nonce to Supabase, hashed nonce to Apple.
  Apple only returns name/email on first sign-in — persist immediately.
- **Email auth** uses `signUp(email:password:)` and `signInWithPassword(email:password:)`.
- **Session persistence** is handled by the SDK via iOS Keychain. No extra work needed.

---

## File Layout Reference

```
Sources/
  Services/
    Supabase.swift           <- SupabaseClient singleton + Secrets
    CadenceSupabaseError.swift
    AuthService.swift        <- signInWithApple, signInWithEmail, signOut
    CycleLogService.swift    <- insertCycleLog, fetchTodayLog
    SharingService.swift     <- updateSharingSettings, upsertSharedLog
    PartnerService.swift     <- fetchPartnerSharedLogToday, createInviteLink,
                               validateInviteToken, acceptInvite
  Models/
    CadenceUser.swift
    CycleProfile.swift
    CycleLog.swift           <- CycleLog + InsertCycleLog
    SharingSettings.swift
    PartnerConnection.swift
    InviteLink.swift
    SharedLog.swift          <- SharedLog + UpsertSharedLog
  ViewModels/
    AuthViewModel.swift
    PartnerViewModel.swift   <- Realtime subscription lifecycle
Config/
  Debug.xcconfig             <- gitignored
  Release.xcconfig           <- gitignored
  Debug.xcconfig.template    <- committed
```

---

## Pre-Flight Checklist

Run this before writing any new Supabase-related code:

- [ ] Are credentials read from `Bundle.main.infoDictionary`, not hardcoded?
- [ ] Is the model struct using `CodingKeys` for every snake_case column?
- [ ] Are encrypted fields typed as `String?` (ciphertext) with no auto-decoding?
- [ ] Does every query call `.execute()` or `.single()` to terminate the builder?
- [ ] Is `.upsert` used for `shared_logs` (not `.insert`)?
- [ ] Are dates passed to PostgREST filters as `.ISO8601Format()` strings?
- [ ] Does every Realtime subscription have a matching cleanup in `.onDisappear`?
- [ ] Are all thrown errors mapped to `CadenceSupabaseError` before reaching the view?
- [ ] Is `cycle_logs` only queried from a tracker session, never a partner session?
