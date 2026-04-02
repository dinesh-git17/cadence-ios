import Foundation

final class CycleProfileService {
    /// Creates or updates the cycle profile during onboarding with seed data.
    /// Uses upsert so re-entry after interrupted onboarding is safe.
    func upsertProfile(_ profile: InsertCycleProfile) async throws {
        do {
            try await supabase
                .from("cycle_profiles")
                .upsert(profile)
                .execute()
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }

    /// Fetches the cycle profile for a given user.
    func fetchProfile(userID: UUID) async throws -> CycleProfile {
        do {
            return try await supabase
                .from("cycle_profiles")
                .select()
                .eq("user_id", value: userID)
                .single()
                .execute()
                .value
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }

    /// Updates computed averages after a new cycle completes.
    func updateAverages(
        userID: UUID,
        avgCycleLength: Int,
        avgPeriodDuration: Int
    ) async throws {
        do {
            try await supabase
                .from("cycle_profiles")
                .update([
                    "avg_cycle_length": avgCycleLength,
                    "avg_period_duration": avgPeriodDuration,
                ])
                .eq("user_id", value: userID)
                .execute()
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }
}
