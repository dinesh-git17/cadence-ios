# PredictionEngine — Swift Implementation

Complete source for `PredictionEngine.swift`. Place in
`Cadence/Models/Prediction/PredictionEngine.swift`.

---

## PeriodFlow (if not already defined)

```swift
// Cadence/Models/Cycle/PeriodFlow.swift
enum PeriodFlow: String, Codable, CaseIterable {
    case none
    case spotting
    case light
    case medium
    case heavy

    var isFlow: Bool { self != .none }
}
```

---

## Data Models

```swift
// Cadence/Models/Cycle/CycleRecord.swift
import Foundation

struct CycleRecord: Equatable {
    /// First day of this period. Normalised to start-of-day.
    let startDate: Date
    /// Number of calendar days from first to last period flow log, inclusive.
    let periodDuration: Int
    /// Days from this cycle's start to the next cycle's start.
    /// nil if this is the current (ongoing) cycle.
    let cycleLength: Int?
}
```

```swift
// Cadence/Models/Cycle/CyclePhase.swift
enum CyclePhase: String, CaseIterable, Identifiable {
    case menstrual
    case follicular
    case ovulation
    case luteal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .menstrual:  return "Menstrual"
        case .follicular: return "Follicular"
        case .ovulation:  return "Ovulation"
        case .luteal:     return "Luteal"
        }
    }
}
```

```swift
// Cadence/Models/Cycle/PhaseInterval.swift
import Foundation

struct PhaseInterval: Equatable {
    let phase: CyclePhase
    /// Inclusive start date (normalised to start-of-day).
    let startDate: Date
    /// Exclusive end date — first day of the *next* phase.
    let endDate: Date

    var dateInterval: DateInterval {
        DateInterval(start: startDate, end: endDate)
    }

    /// A zero-duration phase is valid (short cycles can produce a 0-day
    /// follicular phase). Skip rendering these in the UI.
    var isEmpty: Bool { startDate >= endDate }

    func contains(_ date: Date) -> Bool {
        let d = Calendar.current.startOfDay(for: date)
        return d >= startDate && d < endDate
    }
}
```

```swift
// Cadence/Models/Cycle/PredictionConfidence.swift
enum PredictionConfidence: Equatable {
    /// 0 completed cycles — seeded from onboarding only.
    case seed
    /// 1–2 completed cycles.
    case low
    /// 3+ completed cycles.
    case high

    var requiresLabel: Bool { self != .high }

    var localizedLabel: String {
        switch self {
        case .seed: return "Estimated"
        case .low:  return "Low confidence"
        case .high: return ""
        }
    }
}
```

```swift
// Cadence/Models/Cycle/CyclePrediction.swift
import Foundation

struct CyclePrediction {
    /// Predicted start date of the next period.
    let nextPeriodStart: Date
    /// All four phases for the current cycle. Some may be .isEmpty.
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
```

---

## PredictionEngine

```swift
// Cadence/Models/Prediction/PredictionEngine.swift
import Foundation

/// Pure prediction engine — no side effects, no async, no network.
/// Inject this through your view model.
final class PredictionEngine {

    // MARK: - Private state

    private let completedCycles: [CycleRecord]  // Only cycles with non-nil cycleLength
    private let seedCycleLength: Int
    private let seedPeriodDuration: Int
    private let calendar: Calendar

    // MARK: - Init

    /// - Parameters:
    ///   - completedCycles: Cycles with a known `cycleLength` (i.e., not the
    ///     current ongoing cycle). Sorted oldest-first or any order — the
    ///     engine sorts internally.
    ///   - seedCycleLength: Onboarding estimate. Used only when
    ///     completedCycles is empty.
    ///   - seedPeriodDuration: Onboarding estimate. Used only when
    ///     completedCycles is empty.
    init(
        completedCycles: [CycleRecord],
        seedCycleLength: Int = 28,
        seedPeriodDuration: Int = 5,
        calendar: Calendar = .current
    ) {
        // Filter to only completed (non-nil cycleLength), sort oldest-first
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
        case 0:        return .seed
        case 1, 2:     return .low
        default:       return .high
        }
    }

    // MARK: - Weighted Rolling Averages

    /// Weighted cycle length. Linear weights — most recent cycle = weight N,
    /// oldest = weight 1. Falls back to seedCycleLength when no completed cycles.
    var averageCycleLength: Int {
        let lengths = completedCycles.compactMap { $0.cycleLength }
        return weightedAverage(of: lengths) ?? seedCycleLength
    }

    /// Weighted period duration. Same linear weighting scheme.
    var averagePeriodDuration: Int {
        guard !completedCycles.isEmpty else { return seedPeriodDuration }
        let durations = completedCycles.map { $0.periodDuration }
        return weightedAverage(of: durations) ?? seedPeriodDuration
    }

    // MARK: - Core Prediction Methods

    /// Predicted start date of the next period.
    func predictNextPeriodStart(from lastPeriodStart: Date) -> Date {
        let base = calendar.startOfDay(for: lastPeriodStart)
        return calendar.date(byAdding: .day, value: averageCycleLength, to: base)!
    }

    /// The four cycle phases for a cycle that started on `cycleStartDate`.
    /// Some PhaseIntervals may be `.isEmpty` (zero-duration follicular phase
    /// for short cycles). Never returns fewer or more than 4 elements.
    func predictPhases(for cycleStartDate: Date) -> [PhaseInterval] {
        let base = calendar.startOfDay(for: cycleStartDate)
        let cl = averageCycleLength
        let pd = averagePeriodDuration

        // Luteal phase is constant (~14 days). Ovulation day anchors to this.
        let ovulationDay = max(pd + 1, cl - 14)
        let ovStartDay = max(pd + 1, ovulationDay - 3)
        let ovEndDay = ovulationDay + 3

        func dateAt(day: Int) -> Date {
            // day is 1-indexed; add (day - 1) to cycle start
            calendar.date(byAdding: .day, value: day - 1, to: base)!
        }

        // Phase end dates are exclusive (= start of next phase)
        let menstrualEnd  = dateAt(day: pd + 1)
        let follicularEnd = dateAt(day: ovStartDay)      // == menstrualEnd if 0-day follicular
        let ovulationEnd  = dateAt(day: ovEndDay + 1)
        let lutealEnd     = dateAt(day: cl + 1)

        return [
            PhaseInterval(phase: .menstrual,  startDate: base,          endDate: menstrualEnd),
            PhaseInterval(phase: .follicular, startDate: menstrualEnd,  endDate: follicularEnd),
            PhaseInterval(phase: .ovulation,  startDate: follicularEnd, endDate: ovulationEnd),
            PhaseInterval(phase: .luteal,     startDate: ovulationEnd,  endDate: lutealEnd),
        ]
    }

    /// Fertile window for a cycle starting on `cycleStartDate`.
    /// Clamped so it never starts before `cycleStartDate`.
    func fertileWindow(for cycleStartDate: Date) -> DateInterval {
        let base = calendar.startOfDay(for: cycleStartDate)
        let cl = averageCycleLength
        let pd = averagePeriodDuration

        let ovulationDay = max(pd + 1, cl - 14)
        // Fertile: 5 days before ovulation through 1 day after
        let fertileStartDay = max(1, ovulationDay - 5)
        let fertileEndDay = ovulationDay + 1  // exclusive end

        func dateAt(day: Int) -> Date {
            calendar.date(byAdding: .day, value: day - 1, to: base)!
        }

        return DateInterval(start: dateAt(day: fertileStartDay),
                            end: dateAt(day: fertileEndDay + 1))  // end is exclusive
    }

    // MARK: - Full Prediction Package (preferred callsite)

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
    /// Returns nil if the input array is empty.
    private func weightedAverage(of values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let n = values.count
        var weightedSum = 0.0
        var totalWeight = 0.0
        for (index, value) in values.enumerated() {
            let weight = Double(index + 1)   // oldest=1, newest=n
            weightedSum += weight * Double(value)
            totalWeight += weight
        }
        return Int(round(weightedSum / totalWeight))
    }
}
```

---

## CycleRecord Derivation

```swift
// Cadence/Models/Prediction/CycleRecordDeriver.swift
import Foundation

/// Derives structured CycleRecord history from raw day-level CycleLog entries.
/// This is a pure batch transform — call it when rebuilding local prediction state.
enum CycleRecordDeriver {

    /// Minimum gap (in calendar days, from run START) before a new cycle begins.
    static let minimumCycleGapDays = 14

    /// Derive an array of CycleRecords from raw logs.
    ///
    /// The last record in the returned array always has `cycleLength == nil`
    /// (the current ongoing cycle). All earlier records have a non-nil
    /// `cycleLength` and represent completed cycles.
    ///
    /// - Parameter logs: All CycleLog entries for a user. Order does not matter.
    /// - Returns: CycleRecords sorted oldest-first. Empty if no period logs exist.
    static func derive(from logs: [CycleLog], calendar: Calendar = .current) -> [CycleRecord] {
        // 1. Filter to period flow days only, sorted ascending
        let periodLogs = logs
            .filter { ($0.periodFlow ?? .none).isFlow }
            .sorted { $0.date < $1.date }

        guard !periodLogs.isEmpty else { return [] }

        // 2. Group into runs using the 14-day-from-run-start rule
        var runs: [[CycleLog]] = []
        var currentRun: [CycleLog] = [periodLogs[0]]

        for log in periodLogs.dropFirst() {
            let runStart = calendar.startOfDay(for: currentRun[0].date)
            let logDate = calendar.startOfDay(for: log.date)
            let daysSinceRunStart = calendar.dateComponents(
                [.day], from: runStart, to: logDate
            ).day ?? 0

            if daysSinceRunStart < minimumCycleGapDays {
                currentRun.append(log)
            } else {
                runs.append(currentRun)
                currentRun = [log]
            }
        }
        runs.append(currentRun)

        // 3. Filter out single-day spotting-only runs (ambiguous; not a true period)
        //    A run is kept if it spans 2+ days OR contains at least one non-spotting log.
        let filteredRuns = runs.filter { run in
            let spanDays = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: run.first!.date),
                to: calendar.startOfDay(for: run.last!.date)
            ).day ?? 0
            let hasNonSpotting = run.contains { $0.periodFlow != .spotting }
            return spanDays >= 1 || hasNonSpotting
        }

        guard !filteredRuns.isEmpty else { return [] }

        // 4. Convert runs to CycleRecords with nil cycleLength initially
        var records: [CycleRecord] = filteredRuns.map { run in
            let start = calendar.startOfDay(for: run.first!.date)
            let end   = calendar.startOfDay(for: run.last!.date)
            let duration = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            return CycleRecord(startDate: start, periodDuration: duration, cycleLength: nil)
        }

        // 5. Back-fill cycleLength for all completed cycles (all but the last)
        for i in 0..<(records.count - 1) {
            let days = calendar.dateComponents(
                [.day],
                from: records[i].startDate,
                to: records[i + 1].startDate
            ).day
            records[i] = CycleRecord(
                startDate: records[i].startDate,
                periodDuration: records[i].periodDuration,
                cycleLength: days
            )
        }

        return records
    }

    /// Returns only the completed cycles (cycleLength != nil), which are the
    /// input for PredictionEngine.
    static func completedCycles(from logs: [CycleLog], calendar: Calendar = .current) -> [CycleRecord] {
        derive(from: logs, calendar: calendar).filter { $0.cycleLength != nil }
    }
}
```

---

## CycleLog Stub

If `CycleLog` is not yet defined, use this minimum definition:

```swift
struct CycleLog {
    let date: Date
    let periodFlow: PeriodFlow?
    // Other fields (mood, energy, etc.) not needed by the prediction engine
}
```
