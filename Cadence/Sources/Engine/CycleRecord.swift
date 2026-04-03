import Foundation

/// A single menstrual cycle derived from logged data.
/// `cycleLength` is nil for the current (ongoing) cycle.
struct CycleRecord: Equatable {
    /// First day of this period, normalised to start-of-day.
    let startDate: Date
    /// Number of calendar days from first to last period flow log, inclusive.
    let periodDuration: Int
    /// Days from this cycle's start to the next cycle's start.
    /// nil if this is the current ongoing cycle.
    let cycleLength: Int?
}
