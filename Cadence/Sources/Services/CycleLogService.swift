import Foundation

final class CycleLogService {
    /// Inserts an encrypted cycle log. Caller must encrypt all fields before calling.
    func insertCycleLog(_ log: InsertCycleLog) async throws {
        do {
            try await supabase
                .from("cycle_logs")
                .insert(log)
                .execute()
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }

    /// Upserts a cycle log (insert or update by user_id + log_date).
    func upsertCycleLog(_ log: InsertCycleLog) async throws {
        do {
            try await supabase
                .from("cycle_logs")
                .upsert(log, onConflict: "user_id,log_date")
                .execute()
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }

    /// Fetches today's log for the given user. Returns nil if not yet logged.
    func fetchTodayLog(userID: UUID) async throws -> CycleLog? {
        let today = Calendar.current.startOfDay(for: Date())
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else {
            return nil
        }

        do {
            let logs: [CycleLog] = try await supabase
                .from("cycle_logs")
                .select()
                .eq("user_id", value: userID)
                .gte("log_date", value: today.ISO8601Format())
                .lt("log_date", value: tomorrow.ISO8601Format())
                .limit(1)
                .execute()
                .value
            return logs.first
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }

    /// Fetches the log for a specific date.
    func fetchLog(userID: UUID, date: Date) async throws -> CycleLog? {
        let dayStart = Calendar.current.startOfDay(for: date)
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }

        do {
            let logs: [CycleLog] = try await supabase
                .from("cycle_logs")
                .select()
                .eq("user_id", value: userID)
                .gte("log_date", value: dayStart.ISO8601Format())
                .lt("log_date", value: dayEnd.ISO8601Format())
                .limit(1)
                .execute()
                .value
            return logs.first
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }

    /// Fetches all logs in a date range (inclusive start, exclusive end).
    func fetchLogs(userID: UUID, from startDate: Date, to endDate: Date) async throws -> [CycleLog] {
        do {
            return try await supabase
                .from("cycle_logs")
                .select()
                .eq("user_id", value: userID)
                .gte("log_date", value: startDate.ISO8601Format())
                .lt("log_date", value: endDate.ISO8601Format())
                .order("log_date", ascending: true)
                .execute()
                .value
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }
}
