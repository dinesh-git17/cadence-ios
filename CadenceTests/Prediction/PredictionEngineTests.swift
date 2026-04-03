@testable import Cadence
import XCTest

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

        // Menstrual: days 1-5 (March 1-5, end = March 6 exclusive)
        let menstrual = phases[0]
        XCTAssertEqual(menstrual.phase, .menstrual)
        XCTAssertEqual(menstrual.startDate, Date.test(2024, 3, 1))
        XCTAssertEqual(menstrual.endDate, Date.test(2024, 3, 6))
        XCTAssertFalse(menstrual.isEmpty)

        // Follicular: days 6-10 (March 6-10, end = March 11 exclusive)
        let follicular = phases[1]
        XCTAssertEqual(follicular.phase, .follicular)
        XCTAssertEqual(follicular.startDate, Date.test(2024, 3, 6))
        XCTAssertEqual(follicular.endDate, Date.test(2024, 3, 11))
        XCTAssertFalse(follicular.isEmpty)

        // Ovulation: days 11-17 (March 11-17, end = March 18 exclusive)
        let ovulation = phases[2]
        XCTAssertEqual(ovulation.phase, .ovulation)
        XCTAssertEqual(ovulation.startDate, Date.test(2024, 3, 11))
        XCTAssertEqual(ovulation.endDate, Date.test(2024, 3, 18))
        XCTAssertFalse(ovulation.isEmpty)

        // Luteal: days 18-28 (March 18-28, end = March 29 exclusive)
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
        // ovulationDay = 14; fertileStart = day 9 (March 9); fertileEnd = day 16 (March 16)
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
        // So follicular end = start = March 6 -> isEmpty
        let sut = engine(cycleLengths: [21, 21, 21], periodDuration: 5)
        let phases = sut.predictPhases(for: Date.test(2024, 3, 1))

        let follicular = phases[1]
        XCTAssertEqual(follicular.phase, .follicular)
        XCTAssertTrue(
            follicular.isEmpty,
            "21-day cycle with 5-day period should produce zero-duration follicular"
        )

        // Ovulation: days 6-10 (March 6-10)
        let ovulation = phases[2]
        XCTAssertEqual(ovulation.startDate, Date.test(2024, 3, 6))
        XCTAssertEqual(ovulation.endDate, Date.test(2024, 3, 11))

        // Luteal: days 11-21 (March 11-21)
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
        XCTAssertEqual(ovulation.endDate, Date.test(2024, 3, 25))

        let luteal = phases[3]
        XCTAssertEqual(luteal.startDate, Date.test(2024, 3, 25))
        XCTAssertEqual(luteal.endDate, Date.test(2024, 4, 5))
    }

    // MARK: - 4. Irregular Cycles — Weighted Average Tracks Trend

    func testIrregularCycles_weightedAverageShorterThanSimple() {
        // Trending shorter: [30, 28, 26, 24, 22] — last 28 is ongoing (discarded)
        // Completed: [30, 28, 26, 24, 22]; Weighted: 24.67 -> 25
        let sut = engine(cycleLengths: [30, 28, 26, 24, 22, 28])
        XCTAssertEqual(sut.averageCycleLength, 25, "Weighted average should track the shortening trend")
    }

    func testIrregularCycles_weightedAverageLongerThanSimple() {
        // Trending longer: [22, 24, 26, 28, 30] — last 28 is ongoing (discarded)
        // Completed: [22, 24, 26, 28, 30]; Weighted: 27.33 -> 27
        let sut = engine(cycleLengths: [22, 24, 26, 28, 30, 28])
        XCTAssertEqual(sut.averageCycleLength, 27)
    }

    func testIrregularCycles_oldSpikeDownweighted() {
        // Anomalous long cycle in the past: [45, 28, 28, 28, 28] — last 28 is ongoing
        // Completed: [45, 28, 28, 28, 28]; Weighted: 29.1 -> 29
        let sut = engine(cycleLengths: [45, 28, 28, 28, 28, 28])
        XCTAssertEqual(sut.averageCycleLength, 29)
    }

    func testSingleCycle_usesOnlyThatValue() {
        // [27, 28]: first is completed (cycleLength=27), second is ongoing
        let sut = engine(cycleLengths: [27, 28])
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
        // [28, 28]: 1 completed + 1 ongoing
        XCTAssertEqual(engine(cycleLengths: [28, 28]).confidence, .low)
    }

    func testConfidenceTier_low_twoCycles() {
        // [28, 28, 28]: 2 completed + 1 ongoing
        XCTAssertEqual(engine(cycleLengths: [28, 28, 28]).confidence, .low)
    }

    func testConfidenceTier_high_threeCycles() {
        // [28, 28, 28, 28]: 3 completed + 1 ongoing
        XCTAssertEqual(engine(cycleLengths: [28, 28, 28, 28]).confidence, .high)
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
            today: Date.test(2024, 3, 2) // 61 days later
        )
        XCTAssertTrue(pred.isLowConfidenceDueToGap)
    }

    func testSixtyDayGapFlag_notTriggeredAt59Days() {
        let sut = engine(cycleLengths: [28, 28, 28])
        let pred = sut.prediction(
            lastPeriodStart: Date.test(2024, 1, 1),
            today: Date.test(2024, 2, 29) // 59 days later (2024 is a leap year)
        )
        XCTAssertFalse(pred.isLowConfidenceDueToGap)
    }

    func testSixtyDayGapFlag_notTriggeredAt60Days() {
        let sut = engine(cycleLengths: [28, 28, 28])
        let pred = sut.prediction(
            lastPeriodStart: Date.test(2024, 1, 1),
            today: Date.test(2024, 3, 1) // exactly 60 days — threshold is > 60
        )
        XCTAssertFalse(pred.isLowConfidenceDueToGap)
    }

    func testSixtyDayGapFlag_independentOfConfidenceTier() {
        // A high-confidence engine (3+ completed cycles) can still trigger the gap flag
        let sut = engine(cycleLengths: [28, 28, 28, 28])
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
        let ovulation = phases[2]
        XCTAssertEqual(ovulation.startDate, Date.test(2024, 3, 11))
        XCTAssertEqual(ovulation.endDate, Date.test(2024, 3, 18))
    }

    func testOvulationDayAnchor_constantLutealPhase() {
        // Luteal phase should be ~11 days for all non-clamped cycles
        for cycleLength in [21, 24, 26, 28, 30, 32, 35] {
            let sut = engine(
                cycleLengths: Array(repeating: cycleLength, count: 3),
                periodDuration: 5
            )
            let phases = sut.predictPhases(for: Date.test(2024, 3, 1))
            let luteal = phases[3]
            let lutealDays = calendar.dateComponents(
                [.day], from: luteal.startDate, to: luteal.endDate
            ).day ?? 0
            // Luteal should be 11 days for cycles >= 24d with 5d period (no clamping)
            if cycleLength >= 24 {
                XCTAssertEqual(lutealDays, 11, "Expected 11-day luteal for \(cycleLength)-day cycle")
            }
        }
    }

    // MARK: - 10. Fertile Window Clamping

    func testFertileWindow_standardCycle() {
        let sut = engine(cycleLengths: [28, 28, 28], periodDuration: 5)
        let fertile = sut.fertileWindow(for: Date.test(2024, 3, 1))
        // ovulationDay=14; fertileStart = day 9 = March 9; fertileEnd = day 16 (exclusive = March 16)
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
