import Foundation

/// Fetched row from `cycle_logs`. Encrypted fields are base64 ciphertext.
/// Decrypt via `EncryptionService` after fetch — never auto-decode on the model.
struct CycleLog: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let logDate: Date

    var periodFlow: String?
    var mood: String?
    var energy: String?
    var symptoms: String?
    var sleepQuality: String?
    var intimacyLogged: String?
    var intimacyProtected: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case logDate = "log_date"
        case periodFlow = "period_flow"
        case mood
        case energy
        case symptoms
        case sleepQuality = "sleep_quality"
        case intimacyLogged = "intimacy_logged"
        case intimacyProtected = "intimacy_protected"
        case notes
    }
}

/// Insert/upsert shape for `cycle_logs`. Caller encrypts all fields before constructing.
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
        case userId = "user_id"
        case logDate = "log_date"
        case periodFlow = "period_flow"
        case mood
        case energy
        case symptoms
        case sleepQuality = "sleep_quality"
        case intimacyLogged = "intimacy_logged"
        case intimacyProtected = "intimacy_protected"
        case notes
    }
}
