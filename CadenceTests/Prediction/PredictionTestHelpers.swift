@testable import Cadence
import Foundation

extension Date {
    /// Creates a date at midnight UTC for a given year/month/day.
    static func test(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        guard let date = cal.date(from: comps) else {
            fatalError("Invalid test date: \(year)-\(month)-\(day)")
        }
        return date
    }
}

/// Builds a chain of CycleRecords from a start date and a sequence of
/// cycle lengths. The last record has cycleLength = nil (ongoing cycle).
func makeRecords(
    startDate: Date,
    cycleLengths: [Int],
    periodDuration: Int = 5
) -> [CycleRecord] {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    var records: [CycleRecord] = []
    var current = startDate
    for (index, length) in cycleLengths.enumerated() {
        let isLast = index == cycleLengths.count - 1
        records.append(CycleRecord(
            startDate: current,
            periodDuration: periodDuration,
            cycleLength: isLast ? nil : length
        ))
        guard let next = cal.date(byAdding: .day, value: length, to: current) else { break }
        current = next
    }
    return records
}

/// Returns a Calendar with UTC timezone for consistent test behaviour.
var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return cal
}
