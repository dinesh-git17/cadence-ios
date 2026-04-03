import Foundation

struct CyclePrediction {
    /// Predicted start date of the next period.
    let nextPeriodStart: Date
    /// All four phases for the current cycle. Some may be `.isEmpty`.
    let phases: [PhaseInterval]
    /// Fertile window for this cycle.
    let fertileWindow: DateInterval
    /// Prediction quality based on how many completed cycles are available.
    let confidence: PredictionConfidence
    /// true when today is past nextPeriodStart and no period has been logged.
    let isLate: Bool
    /// true when more than 60 days have passed since the last known period start.
    let isLowConfidenceDueToGap: Bool

    /// The phase that contains a given date, or nil if outside this cycle.
    func phase(for date: Date) -> PhaseInterval? {
        phases.first { $0.contains(date) && !$0.isEmpty }
    }
}
