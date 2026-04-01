---
name: cadence-partner-sharing
description: >
  Complete architecture reference for the Cadence iOS app partner sharing system.
  Read this skill in full before implementing ANY feature that touches partner connections,
  shared data visibility, sharing settings, invite links, or the PartnerViewModel.
  This skill defines every invariant, data flow, and edge case in the sharing architecture.
  Use it when building: partner tab UI, sharing settings toggles, log save flows, invite
  generation/acceptance, disconnect flows, or any Supabase query that involves shared_logs,
  sharing_settings, partner_connections, or invite_links. Violations of the invariants
  documented here are security bugs, not logic bugs.
---

# Cadence — Partner Sharing Architecture

> **Read this entire skill before writing a single line of partner sharing code.**
> The invariants in Section 1 are security requirements. Everything else is derived from them.

---

## Reference Files — Load Before Coding

| File                                  | Load when...                                               |
| ------------------------------------- | ---------------------------------------------------------- |
| `references/models.md`               | Implementing or modifying sharing data models              |
| `references/write-flow.md`           | Building or modifying the SharedLog write path on log save |
| `references/settings-flow.md`        | Implementing sharing settings toggles, backfill, or clear  |
| `references/disconnect-flow.md`      | Implementing the disconnect sequence                       |
| `references/partner-viewmodel.md`    | Building the PartnerViewModel, realtime subscription       |
| `references/invite-flow.md`          | Invite link generation, deep link handling, acceptance     |

Always load the relevant reference file(s) before writing implementation code.

---

## 1. The Core Invariant

**A partner's Supabase session MUST NEVER query `cycle_logs` under any circumstance.**

This is not a preference. It is the privacy guarantee of the product.

All partner reads go through `shared_logs` only. Supabase Row Level Security enforces
this at the database level. Any code that appears to give a partner user direct access
to `cycle_logs` — regardless of how it is filtered, scoped, or wrapped — is a security
bug and must not be shipped.

### RLS Summary

| Table | Partner Session | Tracker Session |
|---|---|---|
| `cycle_logs` | No read, no write, ever | Own rows only |
| `shared_logs` | Read rows where `partner_user_id = auth.uid()` | Write own rows |
| `sharing_settings` | Read only | Read + write own row |
| `partner_connections` | Read own connection | Read own connection |
| `invite_links` | No access | Own rows only |

**Implementation check:** When writing any Supabase query that runs in a partner
user's context, verify the table is `shared_logs` or `sharing_settings` or
`partner_connections`. If you are querying `cycle_logs` in partner context, stop
and redesign.

---

## 2. Category Taxonomy

### Shareable Categories (opt-in, all off by default)

| Category | `sharing_settings` column | `shared_logs` field | Notes |
|---|---|---|---|
| Period (flow + dates) | `share_period` | `period_flow` | Encrypted |
| Symptoms | `share_symptoms` | `symptoms` | Encrypted, array |
| Mood | `share_mood` | `mood` | Encrypted, array |
| Energy level | `share_energy` | `energy` | Encrypted |

### Always-Present in shared_logs (never gated)

These three fields are always written to `shared_logs` when a connection exists,
regardless of sharing settings:

- `cycle_day` — Integer, day number in current cycle
- `cycle_phase` — String enum: `"menstrual"` | `"follicular"` | `"ovulation"` | `"luteal"`
- `predicted_next_period` — ISO8601 date string

Phase information is always shared. It is the minimum useful data for the partner experience.

### Always-Private Categories (never writable to shared_logs)

| Category | `cycle_logs` field(s) | Reason |
|---|---|---|
| Sex / Intimacy | `intimacy_logged`, `intimacy_protected` | Explicit privacy-by-design |
| Sleep quality | `sleep_quality` | Low partner value, personal |
| Notes | `notes` | Free text, always private, no exceptions |

**Implementation check:** If you see code attempting to write `intimacy_logged`,
`sleep_quality`, or `notes` to `shared_logs`, remove it. These fields do not exist
in `shared_logs` and must not be added.

---

## 3. Data Flow Summaries

### SharedLog Write (on log save)

See `references/write-flow.md` for full implementation.

1. Encrypt and write full log to `cycle_logs`
2. Fetch current `sharing_settings`
3. Check for active partner connection (skip if none)
4. Compute cycle context (day, phase, predicted next period)
5. Build `shared_logs` row — only enabled fields + always-present fields
6. Upsert on `(tracker_user_id, log_date)`

### Sharing Settings Change

See `references/settings-flow.md` for full implementation.

- **Disabling:** Null out the field retroactively on all existing `shared_logs` rows
- **Enabling:** Backfill from `cycle_logs` into existing `shared_logs` rows (past 30 days)
- Backfill only updates existing rows — never inserts new ones

### Disconnect

See `references/disconnect-flow.md` for full implementation.

1. Set `partner_connections.status` to `"inactive"`
2. Delete all `shared_logs` rows for this connection pair
3. Clear local state, unsubscribe from realtime
4. Navigate away from partner-dependent screens

### Invite Flow

See `references/invite-flow.md` for full implementation.

- **Generation:** Cryptographic random token, 7-day expiry, deep link URL
- **Acceptance:** Validate token, create `partner_connections` row, mark invite used
- One active invite per tracker at a time
- User cannot connect to themselves

---

## 4. Notification Names

```swift
extension Notification.Name {
    static let partnerConnected    = Notification.Name("cadence.partnerConnected")
    static let partnerDisconnected = Notification.Name("cadence.partnerDisconnected")
}
```

---

## 5. Common Mistakes — Do Not Do These

| Mistake | Why it is wrong | What to do instead |
|---|---|---|
| Querying `cycle_logs` in partner context | Violates the core security invariant | Query `shared_logs` only |
| Writing intimacy/sleep/notes to `shared_logs` | These fields are always private | These fields do not exist in `shared_logs` |
| Inserting new `shared_logs` rows during backfill | Backfill only updates existing rows | Use `.update()`, not `.upsert()`, in backfill |
| Not nulling out disabled categories retroactively | Partner retains stale data after tracker turns sharing off | Always call `clearField()` when disabling |
| Sharing `cycle_day`/`cycle_phase` conditionally | Phase info is always shared with a connected partner | Always write these three fields regardless of settings |
| Forgetting to delete `shared_logs` on disconnect | Partner retains data visibility after disconnect | Delete on disconnect, not lazily |
| Using `.insert()` instead of `.upsert()` in log save | Creates duplicate rows for the same day | Always upsert on `tracker_user_id,log_date` |
| Not checking for active connection before writing | Orphaned rows with no valid `partner_user_id` | Always verify active connection exists first |

---

## 6. File Placement

```
Cadence/
  Services/
    LogService.swift              <- SharedLog write flow on log save
    SharingService.swift          <- Settings toggle, backfill, clear
    InviteService.swift           <- Token generation
  ViewModels/
    PartnerViewModel.swift        <- Connection state, realtime, disconnect
    InviteAcceptanceHandler.swift <- Deep link handling, token validation
  Models/
    SharingSettings.swift         <- ShareCategory enum, SharingSettings struct
    SharedLog.swift               <- SharedLog model, ConnectionStatus enum
```
