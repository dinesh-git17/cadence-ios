import Foundation

/// Derives structured CycleRecord history from raw day-level period logs.
/// This is a pure batch transform — call it when rebuilding local prediction state.
enum CycleRecordDeriver {
    /// Minimum gap (in calendar days, from run START) before a new cycle begins.
    static let minimumCycleGapDays = 14

    /// Derive an array of CycleRecords from raw decrypted period logs.
    ///
    /// The last record in the returned array always has `cycleLength == nil`
    /// (the current ongoing cycle). All earlier records have a non-nil
    /// `cycleLength` and represent completed cycles.
    ///
    /// - Parameters:
    ///   - logs: All decrypted period logs for a user. Order does not matter.
    ///   - calendar: Injectable for deterministic tests.
    /// - Returns: CycleRecords sorted oldest-first. Empty if no period logs exist.
    static func derive(
        from logs: [DecryptedPeriodLog],
        calendar: Calendar = .current
    ) -> [CycleRecord] {
        let runs = groupIntoRuns(logs: logs, calendar: calendar)
        guard !runs.isEmpty else { return [] }

        var records: [CycleRecord] = runs.compactMap { run in
            guard let first = run.first, let last = run.last else { return nil }
            let start = calendar.startOfDay(for: first.date)
            let end = calendar.startOfDay(for: last.date)
            let duration = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            return CycleRecord(startDate: start, periodDuration: duration, cycleLength: nil)
        }

        // Back-fill cycleLength for all completed cycles (all but the last)
        for index in 0 ..< max(0, records.count - 1) {
            let days = calendar.dateComponents(
                [.day],
                from: records[index].startDate,
                to: records[index + 1].startDate
            ).day
            records[index] = CycleRecord(
                startDate: records[index].startDate,
                periodDuration: records[index].periodDuration,
                cycleLength: days
            )
        }

        return records
    }

    /// Returns only the completed cycles (cycleLength != nil), which are the
    /// input for PredictionEngine.
    static func completedCycles(
        from logs: [DecryptedPeriodLog],
        calendar: Calendar = .current
    ) -> [CycleRecord] {
        derive(from: logs, calendar: calendar).filter { $0.cycleLength != nil }
    }

    // MARK: - Private

    /// Groups period-flow logs into runs using the 14-day-from-run-start rule,
    /// then filters out single-day spotting-only runs.
    private static func groupIntoRuns(
        logs: [DecryptedPeriodLog],
        calendar: Calendar
    ) -> [[DecryptedPeriodLog]] {
        let periodLogs = logs
            .filter { ($0.periodFlow ?? .none).isFlow }
            .sorted { $0.date < $1.date }

        guard let firstLog = periodLogs.first else { return [] }

        var runs: [[DecryptedPeriodLog]] = []
        var currentRun: [DecryptedPeriodLog] = [firstLog]

        for log in periodLogs.dropFirst() {
            guard let runStartLog = currentRun.first else { continue }
            let runStart = calendar.startOfDay(for: runStartLog.date)
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

        return runs.filter { run in
            guard let first = run.first, let last = run.last else { return false }
            let spanDays = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: first.date),
                to: calendar.startOfDay(for: last.date)
            ).day ?? 0
            let hasNonSpotting = run.contains { $0.periodFlow != .spotting }
            return spanDays >= 1 || hasNonSpotting
        }
    }
}
