import Foundation

struct PhaseInterval: Equatable {
    let phase: CyclePhase
    /// Inclusive start date, normalised to start-of-day.
    let startDate: Date
    /// Exclusive end date — first day of the next phase.
    let endDate: Date

    var dateInterval: DateInterval {
        DateInterval(start: startDate, end: endDate)
    }

    /// A zero-duration phase is valid (short cycles can produce a 0-day
    /// follicular phase). Skip rendering these in the UI.
    var isEmpty: Bool {
        startDate >= endDate
    }

    func contains(_ date: Date) -> Bool {
        let normalised = Calendar.current.startOfDay(for: date)
        return normalised >= startDate && normalised < endDate
    }
}
