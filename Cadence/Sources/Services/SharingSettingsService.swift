import Foundation

private struct InsertSharingSettings: Encodable {
    let userId: UUID
    let sharePeriod: Bool
    let shareSymptoms: Bool
    let shareMood: Bool
    let shareEnergy: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sharePeriod = "share_period"
        case shareSymptoms = "share_symptoms"
        case shareMood = "share_mood"
        case shareEnergy = "share_energy"
    }
}

final class SharingSettingsService {
    /// Inserts the initial sharing settings row during onboarding.
    /// Uses upsert to handle re-entry (idempotent).
    func upsertSharingSettings(
        userId: UUID,
        sharePeriod: Bool,
        shareMood: Bool,
        shareSymptoms: Bool,
        shareEnergy: Bool
    ) async throws {
        let payload = InsertSharingSettings(
            userId: userId,
            sharePeriod: sharePeriod,
            shareSymptoms: shareSymptoms,
            shareMood: shareMood,
            shareEnergy: shareEnergy
        )
        do {
            try await supabase
                .from("sharing_settings")
                .upsert(payload)
                .execute()
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }

    /// Fetches the current sharing settings for a user.
    func fetchSharingSettings(userId: UUID) async throws -> SharingSettings {
        do {
            return try await supabase
                .from("sharing_settings")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }
}
