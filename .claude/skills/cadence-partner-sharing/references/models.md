# Partner Sharing Data Models — Swift Reference

---

## ShareCategory + SharingSettings

```swift
// MARK: - Sharing

enum ShareCategory: String, CaseIterable {
    case period   = "period"
    case symptoms = "symptoms"
    case mood     = "mood"
    case energy   = "energy"
    // intimacy, sleep, notes are NOT cases — they are never shareable
}

struct SharingSettings: Codable, Equatable {
    var sharePeriod:   Bool = false
    var shareSymptoms: Bool = false
    var shareMood:     Bool = false
    var shareEnergy:   Bool = false

    static let defaults = SharingSettings()

    enum CodingKeys: String, CodingKey {
        case sharePeriod   = "share_period"
        case shareSymptoms = "share_symptoms"
        case shareMood     = "share_mood"
        case shareEnergy   = "share_energy"
    }

    func isEnabled(_ category: ShareCategory) -> Bool {
        switch category {
        case .period:   return sharePeriod
        case .symptoms: return shareSymptoms
        case .mood:     return shareMood
        case .energy:   return shareEnergy
        }
    }
}
```

---

## SharedLog

```swift
struct SharedLog: Codable, Identifiable {
    let id: UUID
    let trackerUserId: UUID
    let partnerUserId: UUID
    let logDate: Date
    // Always present
    let cycleDay: Int
    let cyclePhase: CyclePhase
    let predictedNextPeriod: Date?
    // Conditionally present (nil if category is off or not yet logged)
    var periodFlow: String?    // encrypted
    var symptoms: [String]?    // encrypted
    var mood: [String]?        // encrypted
    var energy: String?        // encrypted

    enum CodingKeys: String, CodingKey {
        case id
        case trackerUserId       = "tracker_user_id"
        case partnerUserId       = "partner_user_id"
        case logDate             = "log_date"
        case cycleDay            = "cycle_day"
        case cyclePhase          = "cycle_phase"
        case predictedNextPeriod = "predicted_next_period"
        case periodFlow          = "period_flow"
        case symptoms, mood, energy
    }
}

enum CyclePhase: String, Codable {
    case menstrual, follicular, ovulation, luteal
}
```

---

## ConnectionStatus

```swift
enum ConnectionStatus {
    case loading
    case disconnected
    case connected(partnerName: String, partnerUserId: UUID)
}
```

---

## ShareCategory Helpers

```swift
extension ShareCategory {
    /// The column name in sharing_settings
    var columnName: String {
        switch self {
        case .period:   return "share_period"
        case .symptoms: return "share_symptoms"
        case .mood:     return "share_mood"
        case .energy:   return "share_energy"
        }
    }

    /// The field name in shared_logs
    var sharedLogsField: String {
        switch self {
        case .period:   return "period_flow"
        case .symptoms: return "symptoms"
        case .mood:     return "mood"
        case .energy:   return "energy"
        }
    }

    /// The field name in cycle_logs
    var cycleLogsField: String {
        switch self {
        case .period:   return "period_flow"
        case .symptoms: return "symptoms"
        case .mood:     return "mood"
        case .energy:   return "energy"
        }
    }
}
```
