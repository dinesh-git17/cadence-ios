/// Prediction quality based on how many completed cycles are available.
enum PredictionConfidence: Equatable {
    /// 0 completed cycles — seeded from onboarding only.
    case seed
    /// 1-2 completed cycles.
    case low
    /// 3+ completed cycles.
    case high

    var requiresLabel: Bool {
        self != .high
    }

    var localizedLabel: String {
        switch self {
            case .seed: "Estimated"
            case .low: "Low confidence"
            case .high: ""
        }
    }
}
