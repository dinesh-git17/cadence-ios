import Foundation

/// Fetched row from `shared_logs`. Encrypted fields are base64 ciphertext.
/// Phase fields (cycleDay, cyclePhase, predictedNextPeriod) are always present and unencrypted.
struct SharedLog: Codable, Identifiable {
    let id: UUID
    let trackerUserId: UUID
    let partnerUserId: UUID
    let logDate: Date

    var periodFlow: String?
    var symptoms: String?
    var mood: String?
    var energy: String?

    let cycleDay: Int
    let cyclePhase: String
    let predictedNextPeriod: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case trackerUserId = "tracker_user_id"
        case partnerUserId = "partner_user_id"
        case logDate = "log_date"
        case periodFlow = "period_flow"
        case symptoms
        case mood
        case energy
        case cycleDay = "cycle_day"
        case cyclePhase = "cycle_phase"
        case predictedNextPeriod = "predicted_next_period"
    }
}

/// Upsert shape for `shared_logs`. Uses `onConflict: "tracker_user_id,log_date"`.
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
        case trackerUserId = "tracker_user_id"
        case partnerUserId = "partner_user_id"
        case logDate = "log_date"
        case periodFlow = "period_flow"
        case symptoms
        case mood
        case energy
        case cycleDay = "cycle_day"
        case cyclePhase = "cycle_phase"
        case predictedNextPeriod = "predicted_next_period"
    }
}
