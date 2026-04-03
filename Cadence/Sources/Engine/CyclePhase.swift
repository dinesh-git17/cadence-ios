import Foundation

enum CyclePhase: String, CaseIterable, Identifiable {
    case menstrual
    case follicular
    case ovulation
    case luteal

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
            case .menstrual: "Menstrual"
            case .follicular: "Follicular"
            case .ovulation: "Ovulation"
            case .luteal: "Luteal"
        }
    }
}
