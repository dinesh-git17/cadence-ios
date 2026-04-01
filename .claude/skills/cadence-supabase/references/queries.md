# Cadence Query Patterns — Swift Reference

All database access lives in service types under `Sources/Services/`. Name services
after the domain they manage: `CycleLogService`, `SharingService`, `PartnerService`.

Each service is a `final class` (or `actor` if state needs concurrency protection).
Services do not hold state — they are stateless query executors. ViewModels hold state.

---

## Insert a New Cycle Log

Callers are responsible for encrypting fields before calling this. Encryption is not
performed inside the service — the service receives ciphertext.

```swift
func insertCycleLog(_ log: InsertCycleLog) async throws {
    do {
        try await supabase
            .from("cycle_logs")
            .insert(log)
            .execute()
    } catch {
        throw CadenceSupabaseError.from(error)
    }
}
```

---

## Fetch Today's Cycle Log for the Current User

```swift
func fetchTodayLog(userID: UUID) async throws -> CycleLog? {
    let today = Calendar.current.startOfDay(for: Date())
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

    do {
        let logs: [CycleLog] = try await supabase
            .from("cycle_logs")
            .select()
            .eq("user_id", value: userID)
            .gte("log_date", value: today.ISO8601Format())
            .lt("log_date", value: tomorrow.ISO8601Format())
            .limit(1)
            .execute()
            .value
        return logs.first
    } catch {
        throw CadenceSupabaseError.from(error)
    }
}
```

**Date formatting note:** Pass dates to Supabase filters as ISO 8601 strings
using `.ISO8601Format()` from `Foundation`. The Supabase Swift SDK's PostgREST
builder accepts `String` for filter values — it does not auto-encode `Date`.

---

## Fetch the Partner's Shared Log for Today

This is called from a **partner session** or from the tracker to populate the
partner card. Partners can only read `shared_logs` where they are `partner_user_id`.

```swift
func fetchPartnerSharedLogToday(partnerUserID: UUID) async throws -> SharedLog? {
    let today = Calendar.current.startOfDay(for: Date())
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

    do {
        let logs: [SharedLog] = try await supabase
            .from("shared_logs")
            .select()
            .eq("partner_user_id", value: partnerUserID)
            .gte("log_date", value: today.ISO8601Format())
            .lt("log_date", value: tomorrow.ISO8601Format())
            .limit(1)
            .execute()
            .value
        return logs.first
    } catch {
        throw CadenceSupabaseError.from(error)
    }
}
```

---

## Update Sharing Settings

```swift
func updateSharingSettings(_ settings: SharingSettings) async throws {
    do {
        try await supabase
            .from("sharing_settings")
            .update(settings)
            .eq("user_id", value: settings.userId)
            .execute()
    } catch {
        throw CadenceSupabaseError.from(error)
    }
}
```

After updating sharing settings, the caller must re-write `shared_logs` to retroactively
clear any categories the user just disabled. Use `upsertSharedLog` (below) with the
updated field set to `nil`.

---

## Create an Invite Link Token

```swift
func createInviteLink(forTrackerID trackerID: UUID) async throws -> InviteLink {
    let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    let expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

    struct InsertInviteLink: Encodable {
        let trackerUserId: UUID
        let token: String
        let expiresAt: Date
        let used: Bool

        enum CodingKeys: String, CodingKey {
            case trackerUserId = "tracker_user_id"
            case token
            case expiresAt     = "expires_at"
            case used
        }
    }

    let payload = InsertInviteLink(
        trackerUserId: trackerID,
        token: token,
        expiresAt: expiresAt,
        used: false
    )

    do {
        let link: InviteLink = try await supabase
            .from("invite_links")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return link
    } catch {
        throw CadenceSupabaseError.from(error)
    }
}
```

---

## Validate an Invite Link Token

```swift
func validateInviteToken(_ token: String) async throws -> InviteLink {
    let now = Date().ISO8601Format()

    do {
        let link: InviteLink = try await supabase
            .from("invite_links")
            .select()
            .eq("token", value: token)
            .eq("used", value: false)
            .gt("expires_at", value: now)
            .single()
            .execute()
            .value
        return link
    } catch {
        // .single() throws when no row is found — map to a meaningful error
        throw CadenceSupabaseError.inviteTokenInvalidOrExpired
    }
}
```

---

## Establish a Partner Connection from an Invite Token

This is a two-step operation: mark the invite as used, then create the connection row.
Both must succeed. If either fails, throw and leave it to the caller to retry.

```swift
func acceptInvite(_ invite: InviteLink, partnerUserID: UUID) async throws {
    // Step 1: Mark token used
    do {
        try await supabase
            .from("invite_links")
            .update(["used": true])
            .eq("id", value: invite.id)
            .execute()
    } catch {
        throw CadenceSupabaseError.from(error)
    }

    // Step 2: Create the connection
    struct InsertConnection: Encodable {
        let trackerUserId: UUID
        let partnerUserId: UUID
        let status: String

        enum CodingKeys: String, CodingKey {
            case trackerUserId = "tracker_user_id"
            case partnerUserId = "partner_user_id"
            case status
        }
    }

    let connection = InsertConnection(
        trackerUserId: invite.trackerUserId,
        partnerUserId: partnerUserID,
        status: "active"
    )

    do {
        try await supabase
            .from("partner_connections")
            .insert(connection)
            .execute()
    } catch {
        throw CadenceSupabaseError.from(error)
    }
}
```

---

## Upsert a Shared Log Row

Used whenever a tracker saves a log or updates sharing settings.

```swift
func upsertSharedLog(_ log: UpsertSharedLog) async throws {
    do {
        try await supabase
            .from("shared_logs")
            .upsert(log, onConflict: "tracker_user_id,log_date")
            .execute()
    } catch {
        throw CadenceSupabaseError.from(error)
    }
}
```

---

## Fetch Sharing Settings (Partner Read)

When the partner needs to know which categories the tracker shares (to render the
"What [name] shares with you" section in the Partner tab):

```swift
func fetchSharingSettings(forTrackerID trackerID: UUID) async throws -> SharingSettings {
    do {
        let settings: SharingSettings = try await supabase
            .from("sharing_settings")
            .select()
            .eq("user_id", value: trackerID)
            .single()
            .execute()
            .value
        return settings
    } catch {
        throw CadenceSupabaseError.from(error)
    }
}
```

This query succeeds from a partner session because the RLS policy on
`sharing_settings` permits reads by connected users.
