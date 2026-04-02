import Foundation

final class NotificationPreferencesService {
    /// Inserts notification preferences during onboarding.
    /// Uses upsert to handle re-entry (idempotent).
    func upsertNotificationPreferences(_ payload: InsertNotificationPreferences) async throws {
        do {
            try await supabase
                .from("notification_preferences")
                .upsert(payload)
                .execute()
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }
}
