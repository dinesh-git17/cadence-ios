import Foundation

struct SharingSettings: Codable {
    let userId: UUID
    var sharePeriod: Bool
    var shareSymptoms: Bool
    var shareMood: Bool
    var shareEnergy: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sharePeriod = "share_period"
        case shareSymptoms = "share_symptoms"
        case shareMood = "share_mood"
        case shareEnergy = "share_energy"
    }
}
