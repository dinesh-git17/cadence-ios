@testable import Cadence
import XCTest

final class CycleRecordDeriverTests: XCTestCase {
    let calendar = utcCalendar

    private func log(_ date: Date, flow: PeriodFlow) -> DecryptedPeriodLog {
        DecryptedPeriodLog(date: date, periodFlow: flow)
    }

    // MARK: - Basic Derivation

    func testBasicDerivation_oneStandardCycle() {
        // Period: Jan 1-5; next period: Jan 29-Feb 2
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
        XCTAssertEqual(records[0].cycleLength, 28) // Jan 29 - Jan 1 = 28 days
        XCTAssertNil(records[1].cycleLength) // Ongoing
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
        // Period starts Jan 1, spotting on Jan 13 (12 days later) -> same run
        let logs = [
            log(.test(2024, 1, 1), flow: .medium),
            log(.test(2024, 1, 2), flow: .light),
            log(.test(2024, 1, 13), flow: .spotting), // 12 days from Jan 1 -> same run
        ]
        let records = CycleRecordDeriver.derive(from: logs, calendar: calendar)
        // Only 1 run (no second period start) -> 1 record, ongoing
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].startDate, .test(2024, 1, 1))
        // Duration: Jan 1 to Jan 13 inclusive = 13 days
        XCTAssertEqual(records[0].periodDuration, 13)
    }

    func testFourteenDayRule_newFlowAt14Days_newCycle() {
        // Period starts Jan 1; new flow on Jan 15 (14 days later) -> new cycle
        let logs = [
            log(.test(2024, 1, 1), flow: .medium),
            log(.test(2024, 1, 2), flow: .light),
            log(.test(2024, 1, 15), flow: .medium), // 14 days from Jan 1 -> new cycle
            log(.test(2024, 1, 16), flow: .heavy),
        ]
        let records = CycleRecordDeriver.derive(from: logs, calendar: calendar)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].startDate, .test(2024, 1, 1))
        XCTAssertEqual(records[0].cycleLength, 14) // Jan 15 - Jan 1 = 14 days
        XCTAssertEqual(records[1].startDate, .test(2024, 1, 15))
        XCTAssertNil(records[1].cycleLength) // Ongoing
    }

    func testFourteenDayRule_exactly13Days_sameRun() {
        // 13 days from run start -> still the same run (< 14)
        let logs = [
            log(.test(2024, 1, 1), flow: .heavy),
            log(.test(2024, 1, 14), flow: .spotting), // Jan 14 - Jan 1 = 13 days
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
        // 3 records total; last is ongoing -> 2 completed
        XCTAssertEqual(completed.count, 2)
        XCTAssertTrue(completed.allSatisfy { $0.cycleLength != nil })
    }

    // MARK: - Period Duration Calculation

    func testPeriodDuration_multiDayPeriod() {
        // Period: Jan 1-5 = 5 days
        let logs = (1 ... 5).map { day in
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
        shuffled.reverse()

        let ordered = CycleRecordDeriver.derive(from: orderedLogs, calendar: calendar)
        let shuffledResult = CycleRecordDeriver.derive(from: shuffled, calendar: calendar)

        XCTAssertEqual(ordered.count, shuffledResult.count)
        XCTAssertEqual(ordered[0].startDate, shuffledResult[0].startDate)
        XCTAssertEqual(ordered[0].cycleLength, shuffledResult[0].cycleLength)
    }
}
