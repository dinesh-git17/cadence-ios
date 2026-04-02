import Foundation

struct NotificationPreferences: Codable {
    let userId: UUID
    var periodReminder: Bool
    var ovulationAlert: Bool
    var dailyLogReminder: Bool
    var partnerActivity: Bool
    var phaseChange: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case periodReminder = "period_reminder"
        case ovulationAlert = "ovulation_alert"
        case dailyLogReminder = "daily_log_reminder"
        case partnerActivity = "partner_activity"
        case phaseChange = "phase_change"
    }
}

struct InsertNotificationPreferences: Encodable {
    let userId: UUID
    let periodReminder: Bool
    let ovulationAlert: Bool
    let dailyLogReminder: Bool
    let partnerActivity: Bool
    let phaseChange: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case periodReminder = "period_reminder"
        case ovulationAlert = "ovulation_alert"
        case dailyLogReminder = "daily_log_reminder"
        case partnerActivity = "partner_activity"
        case phaseChange = "phase_change"
    }
}
