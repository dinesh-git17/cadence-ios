import Foundation

/// Pure prediction engine — no side effects, no async, no network.
/// Inject this through your view model.
final class PredictionEngine {
    // MARK: - Private state

    private let completedCycles: [CycleRecord]
    private let seedCycleLength: Int
    private let seedPeriodDuration: Int
    private let calendar: Calendar

    // MARK: - Init

    /// - Parameters:
    ///   - completedCycles: Cycles with a known `cycleLength` (not the current
    ///     ongoing cycle). Sorted oldest-first internally.
    ///   - seedCycleLength: Onboarding estimate. Used only when
    ///     completedCycles is empty.
    ///   - seedPeriodDuration: Onboarding estimate. Used only when
    ///     completedCycles is empty.
    ///   - calendar: Injectable for deterministic tests.
    init(
        completedCycles: [CycleRecord],
        seedCycleLength: Int = 28,
        seedPeriodDuration: Int = 5,
        calendar: Calendar = .current
    ) {
        self.completedCycles = completedCycles
            .filter { $0.cycleLength != nil }
            .sorted { $0.startDate < $1.startDate }
        self.seedCycleLength = seedCycleLength
        self.seedPeriodDuration = seedPeriodDuration
        self.calendar = calendar
    }

    // MARK: - Confidence Tier

    var confidence: PredictionConfidence {
        switch completedCycles.count {
            case 0: .seed
            case 1, 2: .low
            default: .high
        }
    }

    // MARK: - Weighted Rolling Averages

    /// Weighted cycle length. Linear weights — most recent cycle = weight N,
    /// oldest = weight 1. Falls back to seedCycleLength when no completed cycles.
    var averageCycleLength: Int {
        let lengths = completedCycles.compactMap(\.cycleLength)
        return weightedAverage(of: lengths) ?? seedCycleLength
    }

    /// Weighted period duration. Same linear weighting scheme.
    var averagePeriodDuration: Int {
        guard !completedCycles.isEmpty else { return seedPeriodDuration }
        let durations = completedCycles.map(\.periodDuration)
        return weightedAverage(of: durations) ?? seedPeriodDuration
    }

    // MARK: - Core Prediction Methods

    /// Predicted start date of the next period.
    func predictNextPeriodStart(from lastPeriodStart: Date) -> Date {
        let base = calendar.startOfDay(for: lastPeriodStart)
        return addDays(averageCycleLength, to: base)
    }

    /// The four cycle phases for a cycle that started on `cycleStartDate`.
    /// Some PhaseIntervals may be `.isEmpty` (zero-duration follicular phase
    /// for short cycles). Always returns exactly 4 elements.
    func predictPhases(for cycleStartDate: Date) -> [PhaseInterval] {
        let base = calendar.startOfDay(for: cycleStartDate)
        let cl = averageCycleLength
        let pd = averagePeriodDuration

        let ovulationDay = max(pd + 1, cl - 14)
        let ovStartDay = max(pd + 1, ovulationDay - 3)
        let ovEndDay = ovulationDay + 3

        let menstrualEnd = dateAt(day: pd + 1, from: base)
        let follicularEnd = dateAt(day: ovStartDay, from: base)
        let ovulationEnd = dateAt(day: ovEndDay + 1, from: base)
        let lutealEnd = dateAt(day: cl + 1, from: base)

        return [
            PhaseInterval(phase: .menstrual, startDate: base, endDate: menstrualEnd),
            PhaseInterval(phase: .follicular, startDate: menstrualEnd, endDate: follicularEnd),
            PhaseInterval(phase: .ovulation, startDate: follicularEnd, endDate: ovulationEnd),
            PhaseInterval(phase: .luteal, startDate: ovulationEnd, endDate: lutealEnd),
        ]
    }

    /// Fertile window for a cycle starting on `cycleStartDate`.
    /// Clamped so it never starts before `cycleStartDate`.
    func fertileWindow(for cycleStartDate: Date) -> DateInterval {
        let base = calendar.startOfDay(for: cycleStartDate)
        let cl = averageCycleLength
        let pd = averagePeriodDuration

        let ovulationDay = max(pd + 1, cl - 14)
        let fertileStartDay = max(1, ovulationDay - 5)
        let fertileEndDay = ovulationDay + 1

        let start = dateAt(day: fertileStartDay, from: base)
        let end = dateAt(day: fertileEndDay + 1, from: base)

        return DateInterval(start: start, end: end)
    }

    // MARK: - Full Prediction Package

    /// Assembles a complete CyclePrediction.
    /// - Parameters:
    ///   - lastPeriodStart: Start date of the most recently confirmed period.
    ///   - today: The current date (injectable for testing).
    func prediction(lastPeriodStart: Date, today: Date = Date()) -> CyclePrediction {
        let normalisedLast = calendar.startOfDay(for: lastPeriodStart)
        let normalisedToday = calendar.startOfDay(for: today)

        let nextPeriodStart = predictNextPeriodStart(from: normalisedLast)
        let phases = predictPhases(for: normalisedLast)
        let fertile = fertileWindow(for: normalisedLast)

        let isLate = normalisedToday > nextPeriodStart

        let daysSinceLast = calendar.dateComponents(
            [.day], from: normalisedLast, to: normalisedToday
        ).day ?? 0
        let isLowConfidenceDueToGap = daysSinceLast > 60

        return CyclePrediction(
            nextPeriodStart: nextPeriodStart,
            phases: phases,
            fertileWindow: fertile,
            confidence: confidence,
            isLate: isLate,
            isLowConfidenceDueToGap: isLowConfidenceDueToGap
        )
    }

    // MARK: - Private Helpers

    /// Linear-weighted average of an array of integers.
    /// Weight of element at index i (0-based, sorted oldest-first) = i + 1.
    private func weightedAverage(of values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        var weightedSum = 0.0
        var totalWeight = 0.0
        for (index, value) in values.enumerated() {
            let weight = Double(index + 1)
            weightedSum += weight * Double(value)
            totalWeight += weight
        }
        return Int(round(weightedSum / totalWeight))
    }

    /// Safe date-at-day helper. Day is 1-indexed; adds (day - 1) to base.
    private func dateAt(day: Int, from base: Date) -> Date {
        addDays(day - 1, to: base)
    }

    /// Adds calendar days safely. Falls back to base if calendar arithmetic fails.
    private func addDays(_ days: Int, to base: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: base) ?? base
    }
}
