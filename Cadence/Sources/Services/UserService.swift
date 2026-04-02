import Foundation

private struct UpsertUser: Encodable {
    let id: UUID
    let email: String
    let displayName: String
    let isTracker: Bool

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case isTracker = "is_tracker"
    }
}

final class UserService {
    /// Creates or updates the user record in `users` after authentication.
    func upsertUser(id: UUID, email: String, displayName: String, isTracker: Bool) async throws {
        let payload = UpsertUser(
            id: id,
            email: email,
            displayName: displayName,
            isTracker: isTracker
        )

        do {
            try await supabase
                .from("users")
                .upsert(payload)
                .execute()
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }

    /// Fetches the current user's record.
    func fetchUser(id: UUID) async throws -> CadenceUser {
        do {
            return try await supabase
                .from("users")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }

    /// Marks onboarding as complete in the server-side users record.
    func markOnboardingComplete(userId: UUID) async throws {
        do {
            try await supabase
                .from("users")
                .update(["onboarding_complete": true])
                .eq("id", value: userId)
                .execute()
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }

    /// Checks whether the user has completed onboarding server-side.
    func fetchOnboardingComplete(userId: UUID) async throws -> Bool {
        do {
            let user: CadenceUser = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            return user.onboardingComplete
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }
}
