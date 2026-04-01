# SharedLog Encryption and Partner Key Exchange — Swift Reference

---

## The Rule: shared_logs Use the Tracker's Key

`shared_logs` fields are encrypted with the **tracker's derived key**. The partner
decrypts them using a key they derive locally from the same master secret and the
tracker's UUID.

This works because both users receive the same master secret from the Edge Function
post-authentication. Key derivation is deterministic. The "key exchange" is implicit:
knowing the tracker's user ID is sufficient to derive their key.

---

## SharedLogRow Type

```swift
/// Supabase shared_logs row. Written by the tracker's device only.
/// Read by the partner's device. Encrypted with the tracker's key.
struct SharedLogRow: Codable {
    let id: String
    let trackerUserId: String
    let partnerUserId: String
    let logDate: String
    // Always written in plaintext — phase info is always visible to connected partner:
    let cycleDay: Int
    let cyclePhase: String
    let predictedNextPeriod: String?
    // Written only when the corresponding sharing_settings toggle is true.
    // Encrypted with tracker's key:
    var periodFlow: String?
    var symptoms: String?
    var mood: String?
    var energy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case trackerUserId      = "tracker_user_id"
        case partnerUserId      = "partner_user_id"
        case logDate            = "log_date"
        case cycleDay           = "cycle_day"
        case cyclePhase         = "cycle_phase"
        case predictedNextPeriod = "predicted_next_period"
        case periodFlow         = "period_flow"
        case symptoms
        case mood
        case energy
    }
}
```

---

## Building a SharedLogRow from a CycleLog

This runs on the tracker's device, using the tracker's cached key.

```swift
// Cadence/Services/SharedLogService.swift

func buildSharedLogRow(
    from log: CycleLog,
    trackerUserID: String,
    partnerUserID: String,
    sharingSettings: SharingSettings,
    cycleContext: CycleContext        // computed cycle day, phase, predicted next period
) throws -> SharedLogRow {

    let enc = EncryptionService.shared
    let encoder = JSONEncoder()

    func encryptOptional(_ value: String?) throws -> String? {
        guard let value else { return nil }
        return try enc.encrypt(value)
    }

    func encryptArray<T: RawRepresentable>(_ values: [T]) throws -> String?
        where T.RawValue == String
    {
        guard !values.isEmpty else { return nil }
        let rawValues = values.map { $0.rawValue }
        let jsonData = try encoder.encode(rawValues)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw EncryptionError.encryptionFailure("Array JSON encoding failed.")
        }
        return try enc.encrypt(jsonString)
    }

    return SharedLogRow(
        id:                     UUID().uuidString,
        trackerUserId:          trackerUserID,
        partnerUserId:          partnerUserID,
        logDate:                ISO8601DateFormatter.cadenceDateOnly.string(from: log.logDate),
        cycleDay:               cycleContext.cycleDay,
        cyclePhase:             cycleContext.cyclePhase.rawValue,
        predictedNextPeriod:    cycleContext.predictedNextPeriod.map {
            ISO8601DateFormatter.cadenceDateOnly.string(from: $0)
        },
        // Gate each field on the corresponding sharing toggle.
        // If the toggle is off, write nil — the field does not exist in Supabase.
        periodFlow: sharingSettings.sharePeriod
            ? try encryptOptional(log.periodFlow?.rawValue)
            : nil,
        symptoms: sharingSettings.shareSymptoms
            ? try encryptArray(log.symptoms)
            : nil,
        mood: sharingSettings.shareMood
            ? try encryptArray(log.mood)
            : nil,
        energy: sharingSettings.shareEnergy
            ? try encryptOptional(log.energy?.rawValue)
            : nil
    )
}
```

---

## Partner Decryption of SharedLogRow

The partner derives the tracker's key, then decrypts each field using that key —
not their own cached key.

```swift
// Cadence/Services/SharedLogService.swift

func decryptSharedLog(
    _ row: SharedLogRow,
    masterSecret: Data          // the partner's copy of the app master secret
) throws -> DecryptedSharedLog {

    // Derive the TRACKER's key (not the partner's own key).
    let trackerKey = try EncryptionService.shared.deriveKey(
        from: masterSecret,
        userID: row.trackerUserId
    )

    let enc = EncryptionService.shared
    let decoder = JSONDecoder()

    func decryptOptional(_ value: String?) throws -> String? {
        guard let value else { return nil }
        return try enc.decrypt(value, using: trackerKey)
    }

    func decryptArray<T: RawRepresentable>(_ value: String?) throws -> [T]
        where T.RawValue == String, T: Decodable
    {
        guard let ciphertext = value else { return [] }
        let jsonString = try enc.decrypt(ciphertext, using: trackerKey)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw EncryptionError.decryptionFailure("Array JSON is not valid UTF-8.")
        }
        let rawValues = try decoder.decode([String].self, from: jsonData)
        return rawValues.compactMap { T(rawValue: $0) }
    }

    return DecryptedSharedLog(
        logDate:            ISO8601DateFormatter.cadenceDateOnly.date(from: row.logDate),
        cycleDay:           row.cycleDay,
        cyclePhase:         CyclePhase(rawValue: row.cyclePhase),
        predictedNextPeriod: row.predictedNextPeriod.flatMap {
            ISO8601DateFormatter.cadenceDateOnly.date(from: $0)
        },
        periodFlow:         try decryptOptional(row.periodFlow).flatMap(PeriodFlow.init),
        symptoms:           try decryptArray(row.symptoms),
        mood:               try decryptArray(row.mood),
        energy:             try decryptOptional(row.energy).flatMap(EnergyLevel.init)
    )
}
```

---

## Key Exchange — What This Means in Practice

The key exchange is not a separate protocol step. It is an implicit property of
the derivation scheme:

1. Both tracker and partner authenticate with Supabase.
2. Both call the `/vault/master-secret` Edge Function and receive the same master secret.
3. The tracker's user ID is stored in `partner_connections` — the partner already has it.
4. The partner calls `EncryptionService.shared.deriveKey(from: masterSecret, userID: trackerUserID)`.
5. This produces the exact same key the tracker uses to encrypt their shared_logs.

**Security note**: The master secret is the trust anchor for all user keys. Whoever
holds the master secret can derive any user's encryption key. The master secret must
be delivered only to authenticated sessions and must never be logged, cached to disk,
or included in crash reports.
