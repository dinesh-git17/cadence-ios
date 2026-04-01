# PredictionEngine — Unit Tests

Complete source for `PredictionEngineTests.swift`. Place in
`CadenceTests/Prediction/PredictionEngineTests.swift`.

---

## Test Helpers

```swift
// CadenceTests/Prediction/PredictionTestHelpers.swift
import Foundation
@testable import Cadence

extension Date {
    /// Creates a date at midnight UTC for a given year/month/day.
    /// All test dates are normalised to start-of-day to eliminate time zone noise.
    static func test(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = 0; comps.minute = 0; comps.second = 0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: comps)!
    }
}

/// Builds a chain of CycleRecords from a start date and a sequence of
/// cycle lengths. The last record has cycleLength = nil (ongoing cycle).
func makeRecords(startDate: Date, cycleLengths: [Int], periodDuration: Int = 5) -> [CycleRecord] {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    var records: [CycleRecord] = []
    var current = startDate
    for (i, length) in cycleLengths.enumerated() {
        let isLast = i == cycleLengths.count - 1
        records.append(CycleRecord(
            startDate: current,
            periodDuration: periodDuration,
            cycleLength: isLast ? nil : length
        ))
        current = cal.date(byAdding: .day, value: length, to: current)!
    }
    return records
}

/// Returns a Calendar with UTC timezone for consistent test behaviour.
var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}
```

---

## PredictionEngineTests

```swift
// CadenceTests/Prediction/PredictionEngineTests.swift
import XCTest
@testable import Cadence

final class PredictionEngineTests: XCTestCase {

    let calendar = utcCalendar

    // MARK: - Helpers

    private func engine(
        cycleLengths: [Int],
        periodDuration: Int = 5,
        seedCycleLength: Int = 28,
        seedPeriodDuration: Int = 5,
        startDate: Date = .test(2024, 1, 1)
    ) -> PredictionEngine {
        let records = makeRecords(
            startDate: startDate,
            cycleLengths: cycleLengths,
            periodDuration: periodDuration
        )
        // Only feed completed cycles (non-nil cycleLength) to the engine
        let completed = records.filter { $0.cycleLength != nil }
        return PredictionEngine(
            completedCycles: completed,
            seedCycleLength: seedCycleLength,
            seedPeriodDuration: seedPeriodDuration,
            calendar: calendar
        )
    }

    // MARK: - 1. Standard 28-Day Cycle

    func testStandard28DayCycle_averageCycleLength() {
        let sut = engine(cycleLengths: [28, 28, 28])
        XCTAssertEqual(sut.averageCycleLength, 28)
    }

    func testStandard28DayCycle_predictNextPeriodStart() {
        let sut = engine(cycleLengths: [28, 28, 28])
        let lastStart = Date.test(2024, 3, 1)
        let predicted = sut.predictNextPeriodStart(from: lastStart)
        XCTAssertEqual(predicted, Date.test(2024, 3, 29))
    }

    func testStandard28DayCycle_phases() {
        let sut = engine(cycleLengths: [28, 28, 28], periodDuration: 5)
        let cycleStart = Date.test(2024, 3, 1)
        let phases = sut.predictPhases(for: cycleStart)

        XCTAssertEqual(phases.count, 4)

        // Menstrual: days 1–5 (March 1–5, end = March 6 exclusive)
        let menstrual = phases[0]
        XCTAssertEqual(menstrual.phase, .menstrual)
        XCTAssertEqual(menstrual.startDate, Date.test(2024, 3, 1))
        XCTAssertEqual(menstrual.endDate, Date.test(2024, 3, 6))
        XCTAssertFalse(menstrual.isEmpty)

        // Follicular: days 6–10 (March 6–10, end = March 11 exclusive)
        let follicular = phases[1]
        XCTAssertEqual(follicular.phase, .follicular)
        XCTAssertEqual(follicular.startDate, Date.test(2024, 3, 6))
        XCTAssertEqual(follicular.endDate, Date.test(2024, 3, 11))
        XCTAssertFalse(follicular.isEmpty)

        // Ovulation: days 11–17 (March 11–17, end = March 18 exclusive)
        // ovulationDay = 28-14 = 14; start = 14-3 = 11; end = 14+3 = 17
        let ovulation = phases[2]
        XCTAssertEqual(ovulation.phase, .ovulation)
        XCTAssertEqual(ovulation.startDate, Date.test(2024, 3, 11))
        XCTAssertEqual(ovulation.endDate, Date.test(2024, 3, 18))
        XCTAssertFalse(ovulation.isEmpty)

        // Luteal: days 18–28 (March 18–28, end = March 29 exclusive)
        let luteal = phases[3]
        XCTAssertEqual(luteal.phase, .luteal)
        XCTAssertEqual(luteal.startDate, Date.test(2024, 3, 18))
        XCTAssertEqual(luteal.endDate, Date.test(2024, 3, 29))
        XCTAssertFalse(luteal.isEmpty)
    }

    func testStandard28DayCycle_fertileWindow() {
        let sut = engine(cycleLengths: [28, 28, 28], periodDuration: 5)
        let cycleStart = Date.test(2024, 3, 1)
        let fertile = sut.fertileWindow(for: cycleStart)
        // ovulationDay = 14; fertileStart = day 9 (March 9); fertileEnd = day 15+1 = March 16
        XCTAssertEqual(fertile.start, Date.test(2024, 3, 9))
        XCTAssertEqual(fertile.end, Date.test(2024, 3, 16))
    }

    // MARK: - 2. Short Cycle — 21 Days

    func testShortCycle21Days_averageCycleLength() {
        let sut = engine(cycleLengths: [21, 21, 21])
        XCTAssertEqual(sut.averageCycleLength, 21)
    }

    func testShortCycle21Days_predictNextPeriodStart() {
        let sut = engine(cycleLengths: [21, 21, 21])
        let predicted = sut.predictNextPeriodStart(from: Date.test(2024, 3, 1))
        XCTAssertEqual(predicted, Date.test(2024, 3, 22))
    }

    func testShortCycle21Days_phases_zeroFollicular() {
        // 21-day cycle, 5-day period: follicular should be zero-duration
        // ovulationDay = max(6, 21-14) = max(6, 7) = 7
        // ovStartDay = max(6, 7-3) = max(6, 4) = 6
        // So follicular end = start = March 6 → isEmpty
        let sut = engine(cycleLengths: [21, 21, 21], periodDuration: 5)
        let phases = sut.predictPhases(for: Date.test(2024, 3, 1))

        let follicular = phases[1]
        XCTAssertEqual(follicular.phase, .follicular)
        XCTAssertTrue(follicular.isEmpty, "21-day cycle with 5-day period should produce zero-duration follicular")

        // Ovulation: days 6–10 (March 6–10)
        let ovulation = phases[2]
        XCTAssertEqual(ovulation.startDate, Date.test(2024, 3, 6))
        XCTAssertEqual(ovulation.endDate, Date.test(2024, 3, 11))

        // Luteal: days 11–21 (March 11–21)
        let luteal = phases[3]
        XCTAssertEqual(luteal.startDate, Date.test(2024, 3, 11))
        XCTAssertEqual(luteal.endDate, Date.test(2024, 3, 22))
    }

    // MARK: - 3. Long Cycle — 35 Days

    func testLongCycle35Days_averageCycleLength() {
        let sut = engine(cycleLengths: [35, 35, 35])
        XCTAssertEqual(sut.averageCycleLength, 35)
    }

    func testLongCycle35Days_phases() {
        // 35-day cycle, 5-day period
        // ovulationDay = 35-14 = 21; ovStart = 21-3 = 18; ovEnd = 21+3 = 24
        let sut = engine(cycleLengths: [35, 35, 35], periodDuration: 5)
        let phases = sut.predictPhases(for: Date.test(2024, 3, 1))

        let ovulation = phases[2]
        XCTAssertEqual(ovulation.startDate, Date.test(2024, 3, 18))
        XCTAssertEqual(ovulation.endDate, Date.test(2024, 3, 25))  // exclusive

        let luteal = phases[3]
        XCTAssertEqual(luteal.startDate, Date.test(2024, 3, 25))
        XCTAssertEqual(luteal.endDate, Date.test(2024, 4, 5))  // day 36 = April 5
    }

    // MARK: - 4. Irregular Cycles — Weighted Average Tracks Trend

    func testIrregularCycles_weightedAverageShorterThanSimple() {
        // Trending shorter: [30, 28, 26, 24, 22]
        // Weighted: 24.67 → 25; Simple: 26.0 → 26
        let sut = engine(cycleLengths: [30, 28, 26, 24, 22])
        XCTAssertEqual(sut.averageCycleLength, 25,
            "Weighted average should track the shortening trend (expected 25, not 26)")
    }

    func testIrregularCycles_weightedAverageLongerThanSimple() {
        // Trending longer: [22, 24, 26, 28, 30]
        // Weighted: 27.33 → 27; Simple: 26.0 → 26
        let sut = engine(cycleLengths: [22, 24, 26, 28, 30])
        XCTAssertEqual(sut.averageCycleLength, 27)
    }

    func testIrregularCycles_oldSpikeDownweighted() {
        // Anomalous long cycle in the past: [45, 28, 28, 28, 28]
        // Weighted: 29.1 → 29; Simple: 31.4 → 31
        // Weighted correctly downweights the old anomaly
        let sut = engine(cycleLengths: [45, 28, 28, 28, 28])
        XCTAssertEqual(sut.averageCycleLength, 29)
    }

    func testSingleCycle_usesOnlyThatValue() {
        let sut = engine(cycleLengths: [27])
        XCTAssertEqual(sut.averageCycleLength, 27)
        XCTAssertEqual(sut.confidence, .low)
    }

    // MARK: - 5. Cold Start

    func testColdStart_usesSeededValues() {
        let sut = PredictionEngine(
            completedCycles: [],
            seedCycleLength: 26,
            seedPeriodDuration: 4,
            calendar: calendar
        )
        XCTAssertEqual(sut.averageCycleLength, 26)
        XCTAssertEqual(sut.averagePeriodDuration, 4)
    }

    func testColdStart_confidence_isSeed() {
        let sut = PredictionEngine(completedCycles: [], calendar: calendar)
        XCTAssertEqual(sut.confidence, .seed)
    }

    func testColdStart_predictionUsesDefaults() {
        let sut = PredictionEngine(
            completedCycles: [],
            seedCycleLength: 28,
            seedPeriodDuration: 5,
            calendar: calendar
        )
        let pred = sut.prediction(
            lastPeriodStart: Date.test(2024, 3, 1),
            today: Date.test(2024, 3, 15)
        )
        XCTAssertEqual(pred.nextPeriodStart, Date.test(2024, 3, 29))
        XCTAssertEqual(pred.confidence, .seed)
    }

    // MARK: - 6. Confidence Tiers

    func testConfidenceTier_seed_zeroCycles() {
        XCTAssertEqual(
            PredictionEngine(completedCycles: [], calendar: calendar).confidence,
            .seed
        )
    }

    func testConfidenceTier_low_oneCycle() {
        XCTAssertEqual(engine(cycleLengths: [28]).confidence, .low)
    }

    func testConfidenceTier_low_twoCycles() {
        XCTAssertEqual(engine(cycleLengths: [28, 28]).confidence, .low)
    }

    func testConfidenceTier_high_threeCycles() {
        XCTAssertEqual(engine(cycleLengths: [28, 28, 28]).confidence, .high)
    }

    func testConfidenceTier_requiresLabel_seed() {
        XCTAssertTrue(PredictionConfidence.seed.requiresLabel)
        XCTAssertEqual(PredictionConfidence.seed.localizedLabel, "Estimated")
    }

    func testConfidenceTier_requiresLabel_low() {
        XCTAssertTrue(PredictionConfidence.low.requiresLabel)
        XCTAssertEqual(PredictionConfidence.low.localizedLabel, "Low confidence")
    }

    func testConfidenceTier_noLabel_high() {
        XCTAssertFalse(PredictionConfidence.high.requiresLabel)
    }

    // MARK: - 7. Late Period Detection

    func testLateDetection_isLate_whenTodayPastPredicted() {
        let sut = engine(cycleLengths: [28, 28, 28])
        // Last period: March 1; predicted next: March 29; today: April 2
        let pred = sut.prediction(
            lastPeriodStart: Date.test(2024, 3, 1),
            today: Date.test(2024, 4, 2)
        )
        XCTAssertTrue(pred.isLate)
    }

    func testLateDetection_notLate_whenTodayBeforePredicted() {
        let sut = engine(cycleLengths: [28, 28, 28])
        let pred = sut.prediction(
            lastPeriodStart: Date.test(2024, 3, 1),
            today: Date.test(2024, 3, 20)
        )
        XCTAssertFalse(pred.isLate)
    }

    func testLateDetection_notLate_whenTodayIsPredictedDate() {
        // Exactly on predicted date — not late yet
        let sut = engine(cycleLengths: [28, 28, 28])
        let pred = sut.prediction(
            lastPeriodStart: Date.test(2024, 3, 1),
            today: Date.test(2024, 3, 29)
        )
        XCTAssertFalse(pred.isLate)
    }

    // MARK: - 8. 60-Day Confidence Gap Flag

    func testSixtyDayGapFlag_triggersAt61Days() {
        let sut = engine(cycleLengths: [28, 28, 28])
        let pred = sut.prediction(
            lastPeriodStart: Date.test(2024, 1, 1),
            today: Date.test(2024, 3, 2)   // 61 days later
        )
        XCTAssertTrue(pred.isLowConfidenceDueToGap)
    }

    func testSixtyDayGapFlag_notTriggeredAt59Days() {
        let sut = engine(cycleLengths: [28, 28, 28])
        let pred = sut.prediction(
            lastPeriodStart: Date.test(2024, 1, 1),
            today: Date.test(2024, 2, 29)  // 59 days later (2024 is a leap year)
        )
        XCTAssertFalse(pred.isLowConfidenceDueToGap)
    }

    func testSixtyDayGapFlag_notTriggeredAt60Days() {
        let sut = engine(cycleLengths: [28, 28, 28])
        let pred = sut.prediction(
            lastPeriodStart: Date.test(2024, 1, 1),
            today: Date.test(2024, 3, 1)   // exactly 60 days — threshold is > 60
        )
        XCTAssertFalse(pred.isLowConfidenceDueToGap)
    }

    func testSixtyDayGapFlag_independentOfConfidenceTier() {
        // A high-confidence engine (3+ cycles) can still trigger the gap flag
        let sut = engine(cycleLengths: [28, 28, 28])
        let pred = sut.prediction(
            lastPeriodStart: Date.test(2024, 1, 1),
            today: Date.test(2024, 3, 5)
        )
        XCTAssertEqual(pred.confidence, .high)
        XCTAssertTrue(pred.isLowConfidenceDueToGap)
    }

    // MARK: - 9. Ovulation Day Anchor

    func testOvulationDayAnchor_28DayCycle() {
        // ovulationDay = 28 - 14 = 14
        // ovStart = max(6, 14-3) = 11; ovEnd = 14+3 = 17
        let sut = engine(cycleLengths: [28, 28, 28], periodDuration: 5)
        let phases = sut.predictPhases(for: Date.test(2024, 3, 1))
        let ov = phases[2]
        XCTAssertEqual(ov.startDate, Date.test(2024, 3, 11))
        XCTAssertEqual(ov.endDate, Date.test(2024, 3, 18))   // exclusive
    }

    func testOvulationDayAnchor_constantLutealPhase() {
        // Luteal phase should be ~11 days for 28d cycle and ~11 days for 35d cycle
        // (The ±3 window means luteal = cycleLength - ovEndDay = cycleLength - (cycleLength-14+3))
        // = cycleLength - cycleLength + 11 = 11 days for all non-clamped cycles
        for cycleLength in [21, 24, 26, 28, 30, 32, 35] {
            let sut = engine(cycleLengths: Array(repeating: cycleLength, count: 3), periodDuration: 5)
            let phases = sut.predictPhases(for: Date.test(2024, 3, 1))
            let luteal = phases[3]
            let lutealDays = calendar.dateComponents([.day], from: luteal.startDate, to: luteal.endDate).day!
            // Luteal should be 11 days for cycles ≥ 24d with 5d period (no clamping)
            // Very short cycles (21d with 5d period) get a slightly compressed luteal due to clamping
            if cycleLength >= 24 {
                XCTAssertEqual(lutealDays, 11, "Expected 11-day luteal for \(cycleLength)-day cycle")
            }
        }
    }

    // MARK: - 10. Fertile Window Clamping

    func testFertileWindow_standardCycle() {
        let sut = engine(cycleLengths: [28, 28, 28], periodDuration: 5)
        let fertile = sut.fertileWindow(for: Date.test(2024, 3, 1))
        // ovulationDay=14; fertileStart = day 9 = March 9; fertileEnd = day 15 (exclusive = March 16)
        XCTAssertEqual(fertile.start, Date.test(2024, 3, 9))
        XCTAssertEqual(fertile.end, Date.test(2024, 3, 16))
    }

    func testFertileWindow_clampedForVeryShortCycle() {
        // 17-day cycle, 5-day period
        // ovulationDay = max(6, 17-14) = max(6,3) = 6
        // fertileStart = max(1, 6-5) = max(1,1) = 1 (clamped to day 1)
        let sut = engine(cycleLengths: [17, 17, 17], periodDuration: 5)
        let fertile = sut.fertileWindow(for: Date.test(2024, 3, 1))
        // fertileStart clamped to day 1 = March 1
        XCTAssertEqual(fertile.start, Date.test(2024, 3, 1))
    }
}
```

---

## CycleRecordDeriverTests

```swift
// CadenceTests/Prediction/CycleRecordDeriverTests.swift
import XCTest
@testable import Cadence

final class CycleRecordDeriverTests: XCTestCase {

    let calendar = utcCalendar

    private func log(_ date: Date, flow: PeriodFlow) -> CycleLog {
        CycleLog(date: date, periodFlow: flow)
    }

    // MARK: - Basic Derivation

    func testBasicDerivation_oneStandardCycle() {
        // Period: Jan 1–5; next period: Jan 29–Feb 2
        let logs = [
            log(.test(2024, 1, 1), flow: .medium),
            log(.test(2024, 1, 2), flow: .heavy),
            log(.test(2024, 1, 3), flow: .medium),
            log(.test(2024, 1, 4), flow: .light),
            log(.test(2024, 1, 5), flow: .spotting),
            log(.test(2024, 1, 29), flow: .medium),
            log(.test(2024, 1, 30), flow: .heavy),
        ]
        let records = CycleRecordDeriver.derive(from: logs, calendar: calendar)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].startDate, .test(2024, 1, 1))
        XCTAssertEqual(records[0].periodDuration, 5)
        XCTAssertEqual(records[0].cycleLength, 28)  // Jan 29 - Jan 1 = 28 days
        XCTAssertNil(records[1].cycleLength)         // Ongoing
    }

    func testBasicDerivation_emptyLogs_returnsEmpty() {
        XCTAssertTrue(CycleRecordDeriver.derive(from: [], calendar: calendar).isEmpty)
    }

    func testBasicDerivation_noFlowLogs_returnsEmpty() {
        let logs = [log(.test(2024, 1, 1), flow: .none)]
        XCTAssertTrue(CycleRecordDeriver.derive(from: logs, calendar: calendar).isEmpty)
    }

    // MARK: - 14-Day Rule: Spotting/Continuation

    func testFourteenDayRule_spottingWithin14Days_sameRun() {
        // Period starts Jan 1, spotting on Jan 13 (12 days later) → same run
        let logs = [
            log(.test(2024, 1, 1), flow: .medium),
            log(.test(2024, 1, 2), flow: .light),
            log(.test(2024, 1, 13), flow: .spotting),  // 12 days from Jan 1 → same run
        ]
        let records = CycleRecordDeriver.derive(from: logs, calendar: calendar)
        // Only 1 run (no second period start) → 1 record, ongoing
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].startDate, .test(2024, 1, 1))
        // Duration: Jan 1 to Jan 13 inclusive = 13 days
        XCTAssertEqual(records[0].periodDuration, 13)
    }

    func testFourteenDayRule_newFlowAt14Days_newCycle() {
        // Period starts Jan 1; new flow on Jan 15 (14 days later) → new cycle
        let logs = [
            log(.test(2024, 1, 1), flow: .medium),
            log(.test(2024, 1, 2), flow: .light),
            log(.test(2024, 1, 15), flow: .medium),  // 14 days from Jan 1 → new cycle
            log(.test(2024, 1, 16), flow: .heavy),
        ]
        let records = CycleRecordDeriver.derive(from: logs, calendar: calendar)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].startDate, .test(2024, 1, 1))
        XCTAssertEqual(records[0].cycleLength, 14)   // Jan 15 - Jan 1 = 14 days
        XCTAssertEqual(records[1].startDate, .test(2024, 1, 15))
        XCTAssertNil(records[1].cycleLength)          // Ongoing
    }

    func testFourteenDayRule_exactly13Days_sameRun() {
        // 13 days from run start → still the same run (< 14)
        let logs = [
            log(.test(2024, 1, 1), flow: .heavy),
            log(.test(2024, 1, 14), flow: .spotting),  // 13 days from Jan 1 (Jan 14 - Jan 1 = 13)
        ]
        let records = CycleRecordDeriver.derive(from: logs, calendar: calendar)
        XCTAssertEqual(records.count, 1)
    }

    // MARK: - Completed Cycles Helper

    func testCompletedCycles_excludesOngoingCycle() {
        let logs = [
            log(.test(2024, 1, 1), flow: .medium),
            log(.test(2024, 1, 29), flow: .medium),
            log(.test(2024, 2, 26), flow: .medium),
        ]
        let completed = CycleRecordDeriver.completedCycles(from: logs, calendar: calendar)
        // 3 records total; last is ongoing → 2 completed
        XCTAssertEqual(completed.count, 2)
        XCTAssertTrue(completed.allSatisfy { $0.cycleLength != nil })
    }

    // MARK: - Period Duration Calculation

    func testPeriodDuration_multiDayPeriod() {
        // Period: Jan 1–5 = 5 days
        let logs = (1...5).map { day in
            log(.test(2024, 1, day), flow: .medium)
        }
        let records = CycleRecordDeriver.derive(from: logs, calendar: calendar)
        XCTAssertEqual(records[0].periodDuration, 5)
    }

    func testPeriodDuration_singleDayLog() {
        let logs = [log(.test(2024, 1, 1), flow: .heavy)]
        let records = CycleRecordDeriver.derive(from: logs, calendar: calendar)
        XCTAssertEqual(records[0].periodDuration, 1)
    }

    // MARK: - Log Order Independence

    func testDerivation_unorderedLogsProduceSameResult() {
        let orderedLogs = [
            log(.test(2024, 1, 1), flow: .medium),
            log(.test(2024, 1, 2), flow: .light),
            log(.test(2024, 1, 29), flow: .heavy),
        ]
        var shuffled = orderedLogs
        shuffled.shuffle()

        let ordered = CycleRecordDeriver.derive(from: orderedLogs, calendar: calendar)
        let shuffledResult = CycleRecordDeriver.derive(from: shuffled, calendar: calendar)

        XCTAssertEqual(ordered.count, shuffledResult.count)
        XCTAssertEqual(ordered[0].startDate, shuffledResult[0].startDate)
        XCTAssertEqual(ordered[0].cycleLength, shuffledResult[0].cycleLength)
    }
}
```
