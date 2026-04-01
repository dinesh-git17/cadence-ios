import Foundation

struct CycleProfile: Codable {
    let userId: UUID
    var lastPeriodDate: Date
    var avgCycleLength: Int?
    var avgPeriodDuration: Int?
    let seededCycleLength: Int
    let seededPeriodDuration: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case lastPeriodDate = "last_period_date"
        case avgCycleLength = "avg_cycle_length"
        case avgPeriodDuration = "avg_period_duration"
        case seededCycleLength = "seeded_cycle_length"
        case seededPeriodDuration = "seeded_period_duration"
    }
}

struct InsertCycleProfile: Encodable {
    let userId: UUID
    let lastPeriodDate: Date
    let seededCycleLength: Int
    let seededPeriodDuration: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case lastPeriodDate = "last_period_date"
        case seededCycleLength = "seeded_cycle_length"
        case seededPeriodDuration = "seeded_period_duration"
    }
}
