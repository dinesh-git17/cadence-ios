# CycleLog Encryption Integration — Swift Reference

---

## Supabase Row Types

Define two separate structs: one for the in-memory domain model (plaintext), one for
the Supabase row (encrypted strings).

```swift
// Cadence/Models/CycleLog.swift

/// In-memory domain model. All fields are plaintext. Never send this to Supabase directly.
struct CycleLog {
    let id: UUID
    let userID: String
    let logDate: Date
    var periodFlow: PeriodFlow?         // enum: none, spotting, light, medium, heavy
    var mood: [Mood]                    // enum array
    var energy: EnergyLevel?            // enum: low, medium, high
    var symptoms: [Symptom]             // enum array
    var sleepQuality: SleepQuality?     // enum: poor, okay, good
    var intimacyLogged: Bool
    var intimacyProtected: Bool?
    var notes: String?
}

/// Supabase row representation. All health fields are base64-encoded AES-GCM ciphertext.
/// Only id, user_id, log_date are stored as plaintext.
struct CycleLogRow: Codable {
    let id: String
    let userId: String
    let logDate: String             // ISO 8601 date string (date only, no time)
    var periodFlow: String?         // encrypted
    var mood: String?               // encrypted JSON array string
    var energy: String?             // encrypted
    var symptoms: String?           // encrypted JSON array string
    var sleepQuality: String?       // encrypted
    var intimacyLogged: String?     // encrypted "true" or "false"
    var intimacyProtected: String?  // encrypted "true" or "false"
    var notes: String?              // encrypted

    enum CodingKeys: String, CodingKey {
        case id
        case userId         = "user_id"
        case logDate        = "log_date"
        case periodFlow     = "period_flow"
        case mood
        case energy
        case symptoms
        case sleepQuality   = "sleep_quality"
        case intimacyLogged     = "intimacy_logged"
        case intimacyProtected  = "intimacy_protected"
        case notes
    }
}
```

---

## Encrypting Before Insert

```swift
// Cadence/Services/CycleLogService.swift

extension CycleLog {

    /// Produces an encrypted CycleLogRow ready for Supabase insert.
    /// Call EncryptionService.shared.loadKey() before this is ever invoked.
    func encrypted() throws -> CycleLogRow {
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
                throw EncryptionError.encryptionFailure("Could not encode array to JSON string.")
            }
            return try enc.encrypt(jsonString)
        }

        let isoDate = ISO8601DateFormatter.cadenceDateOnly.string(from: logDate)

        return CycleLogRow(
            id:                 id.uuidString,
            userId:             userID,
            logDate:            isoDate,
            periodFlow:         try encryptOptional(periodFlow?.rawValue),
            mood:               try encryptArray(mood),
            energy:             try encryptOptional(energy?.rawValue),
            symptoms:           try encryptArray(symptoms),
            sleepQuality:       try encryptOptional(sleepQuality?.rawValue),
            intimacyLogged:     try enc.encrypt(String(intimacyLogged)),
            intimacyProtected:  try encryptOptional(intimacyProtected.map { String($0) }),
            notes:              try encryptOptional(notes)
        )
    }
}
```

---

## Decrypting After Fetch

```swift
extension CycleLogRow {

    /// Decrypts a Supabase row back into the in-memory domain model.
    func decrypted() throws -> CycleLog {
        let enc = EncryptionService.shared
        let decoder = JSONDecoder()

        func decryptOptional(_ value: String?) throws -> String? {
            guard let value else { return nil }
            return try enc.decrypt(value)
        }

        func decryptArray<T: RawRepresentable>(_ value: String?) throws -> [T]
            where T.RawValue == String, T: Decodable
        {
            guard let ciphertext = value else { return [] }
            let jsonString = try enc.decrypt(ciphertext)
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw EncryptionError.decryptionFailure("Decrypted array JSON is not valid UTF-8.")
            }
            let rawValues = try decoder.decode([String].self, from: jsonData)
            // Silently drop unrecognised enum values — forward compatibility.
            return rawValues.compactMap { T(rawValue: $0) }
        }

        let logDate: Date = ISO8601DateFormatter.cadenceDateOnly.date(from: logDate)
            ?? { fatalError("CycleLogRow has malformed log_date: \(logDate)") }()

        let intimacyLoggedDecrypted = try enc.decrypt(
            intimacyLogged ?? { throw EncryptionError.decryptionFailure("intimacy_logged is nil") }()
        )

        return CycleLog(
            id:                 UUID(uuidString: id)!,
            userID:             userId,
            logDate:            logDate,
            periodFlow:         try decryptOptional(periodFlow).flatMap(PeriodFlow.init),
            mood:               try decryptArray(mood),
            energy:             try decryptOptional(energy).flatMap(EnergyLevel.init),
            symptoms:           try decryptArray(symptoms),
            sleepQuality:       try decryptOptional(sleepQuality).flatMap(SleepQuality.init),
            intimacyLogged:     intimacyLoggedDecrypted == "true",
            intimacyProtected:  try decryptOptional(intimacyProtected).map { $0 == "true" },
            notes:              try decryptOptional(notes)
        )
    }
}
```

---

## Date Formatter Convenience

```swift
extension ISO8601DateFormatter {
    /// Date-only formatter for log_date fields. Consistent with Supabase date columns.
    static let cadenceDateOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }()
}
```
