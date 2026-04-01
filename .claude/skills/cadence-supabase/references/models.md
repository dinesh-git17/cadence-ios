# Cadence Model Structs — Swift Reference

All models live in `Sources/Models/`. Each struct is `Codable` and maps exactly to the
Supabase schema. CodingKeys are provided wherever Swift camelCase diverges from SQL snake_case.

**Encoding convention for encrypted fields:** Fields encrypted client-side (AES-GCM via
`CadenceCrypto`) are stored as `String` in model structs — the base64-encoded ciphertext.
Decryption is a separate step performed by `CadenceCrypto` after the row is fetched.
Never add computed properties that auto-decrypt on the model itself; keep models as pure
data containers.

---

## CadenceUser

```swift
// Maps to: public.users
struct CadenceUser: Codable, Identifiable {
    let id: UUID
    let email: String
    let displayName: String
    let isTracker: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case isTracker    = "is_tracker"
        case createdAt    = "created_at"
    }
}
```

---

## CycleProfile

```swift
// Maps to: public.cycle_profiles
// One row per tracker user. Created during onboarding.
struct CycleProfile: Codable {
    let userId: UUID
    var lastPeriodDate: Date
    var avgCycleLength: Int?       // computed, may be null until 1+ cycles complete
    var avgPeriodDuration: Int?    // computed, may be null until 1+ cycles complete
    let seededCycleLength: Int     // onboarding input, never changes
    let seededPeriodDuration: Int  // onboarding input, never changes

    enum CodingKeys: String, CodingKey {
        case userId               = "user_id"
        case lastPeriodDate       = "last_period_date"
        case avgCycleLength       = "avg_cycle_length"
        case avgPeriodDuration    = "avg_period_duration"
        case seededCycleLength    = "seeded_cycle_length"
        case seededPeriodDuration = "seeded_period_duration"
    }
}
```

---

## CycleLog

Encrypted fields are `String?` (ciphertext). The only unencrypted fields are `id`,
`userId`, and `logDate`. Do not attempt to decode encrypted fields into their domain
types at this layer.

```swift
// Maps to: public.cycle_logs
// Encrypted fields store base64(AES-GCM ciphertext). Decrypt with CadenceCrypto.
struct CycleLog: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let logDate: Date

    // Encrypted — String is ciphertext. Decrypt before use.
    var periodFlow: String?         // domain type after decrypt: PeriodFlow (enum)
    var mood: String?               // domain type after decrypt: [MoodTag] (array)
    var energy: String?             // domain type after decrypt: EnergyLevel (enum)
    var symptoms: String?           // domain type after decrypt: [SymptomTag] (array)
    var sleepQuality: String?       // domain type after decrypt: SleepQuality (enum)
    var intimacyLogged: String?     // domain type after decrypt: Bool
    var intimacyProtected: String?  // domain type after decrypt: Bool?
    var notes: String?              // domain type after decrypt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId           = "user_id"
        case logDate          = "log_date"
        case periodFlow       = "period_flow"
        case mood
        case energy
        case symptoms
        case sleepQuality     = "sleep_quality"
        case intimacyLogged   = "intimacy_logged"
        case intimacyProtected = "intimacy_protected"
        case notes
    }
}
```

**Insert shape:** To insert a new log, use a separate `InsertCycleLog` struct with
non-optional encrypted fields as `String` (the caller encrypts before inserting):

```swift
// Used only for INSERT operations — never for decoding fetched rows.
struct InsertCycleLog: Encodable {
    let userId: UUID
    let logDate: Date
    let periodFlow: String?
    let mood: String?
    let energy: String?
    let symptoms: String?
    let sleepQuality: String?
    let intimacyLogged: String?
    let intimacyProtected: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case userId           = "user_id"
        case logDate          = "log_date"
        case periodFlow       = "period_flow"
        case mood
        case energy
        case symptoms
        case sleepQuality     = "sleep_quality"
        case intimacyLogged   = "intimacy_logged"
        case intimacyProtected = "intimacy_protected"
        case notes
    }
}
```

---

## SharingSettings

```swift
// Maps to: public.sharing_settings
// One row per user. Readable by both connected users; writable only by the tracker.
struct SharingSettings: Codable {
    let userId: UUID
    var sharePeriod: Bool
    var shareSymptoms: Bool
    var shareMood: Bool
    var shareEnergy: Bool

    enum CodingKeys: String, CodingKey {
        case userId        = "user_id"
        case sharePeriod   = "share_period"
        case shareSymptoms = "share_symptoms"
        case shareMood     = "share_mood"
        case shareEnergy   = "share_energy"
    }
}
```

---

## PartnerConnection

```swift
// Maps to: public.partner_connections
enum ConnectionStatus: String, Codable {
    case active
    case inactive
}

struct PartnerConnection: Codable, Identifiable {
    let id: UUID
    let trackerUserId: UUID
    let partnerUserId: UUID
    let connectedAt: Date
    let status: ConnectionStatus

    enum CodingKeys: String, CodingKey {
        case id
        case trackerUserId = "tracker_user_id"
        case partnerUserId = "partner_user_id"
        case connectedAt   = "connected_at"
        case status
    }
}
```

---

## InviteLink

```swift
// Maps to: public.invite_links
struct InviteLink: Codable, Identifiable {
    let id: UUID
    let trackerUserId: UUID
    let token: String
    let expiresAt: Date
    let used: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case trackerUserId = "tracker_user_id"
        case token
        case expiresAt     = "expires_at"
        case used
    }
}
```

---

## SharedLog

Phase fields (`cycleDay`, `cyclePhase`, `predictedNextPeriod`) are always written
and never encrypted — they're safe to share with any connected partner. All other
fields mirror `CycleLog` encrypted fields and are `String?` ciphertext.

```swift
// Maps to: public.shared_logs
// Partners read this table. Trackers write it.
// Encrypted fields mirror cycle_logs; null means not shared or not logged.
struct SharedLog: Codable, Identifiable {
    let id: UUID
    let trackerUserId: UUID
    let partnerUserId: UUID
    let logDate: Date

    // Encrypted — null if category not shared
    var periodFlow: String?   // domain: PeriodFlow
    var symptoms: String?     // domain: [SymptomTag]
    var mood: String?         // domain: [MoodTag]
    var energy: String?       // domain: EnergyLevel

    // Always present — never encrypted
    let cycleDay: Int
    let cyclePhase: String    // "menstrual" | "follicular" | "ovulation" | "luteal"
    let predictedNextPeriod: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case trackerUserId        = "tracker_user_id"
        case partnerUserId        = "partner_user_id"
        case logDate              = "log_date"
        case periodFlow           = "period_flow"
        case symptoms
        case mood
        case energy
        case cycleDay             = "cycle_day"
        case cyclePhase           = "cycle_phase"
        case predictedNextPeriod  = "predicted_next_period"
    }
}
```

**Upsert shape:**

```swift
struct UpsertSharedLog: Encodable {
    let trackerUserId: UUID
    let partnerUserId: UUID
    let logDate: Date
    let periodFlow: String?
    let symptoms: String?
    let mood: String?
    let energy: String?
    let cycleDay: Int
    let cyclePhase: String
    let predictedNextPeriod: Date?

    enum CodingKeys: String, CodingKey {
        case trackerUserId       = "tracker_user_id"
        case partnerUserId       = "partner_user_id"
        case logDate             = "log_date"
        case periodFlow          = "period_flow"
        case symptoms
        case mood
        case energy
        case cycleDay            = "cycle_day"
        case cyclePhase          = "cycle_phase"
        case predictedNextPeriod = "predicted_next_period"
    }
}
```
