import Foundation

enum PeriodFlow: String, Codable, CaseIterable {
    case none
    case spotting
    case light
    case medium
    case heavy

    var isFlow: Bool {
        self != .none
    }

    var displayName: String {
        rawValue.capitalized
    }
}
