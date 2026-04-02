import Foundation
import Supabase

private struct InsertInviteLink: Encodable {
    let trackerUserId: UUID
    let token: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case trackerUserId = "tracker_user_id"
        case token
        case expiresAt = "expires_at"
    }
}

/// Response shape from the `accept_invite` RPC function.
private struct AcceptInviteResponse: Decodable {
    let success: Bool
    let error: String?
    let connectionId: UUID?
    let trackerId: UUID?

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case connectionId = "connection_id"
        case trackerId = "tracker_id"
    }
}

/// Response shape from the `validate_invite_token` RPC function.
private struct InviteValidationResponse: Decodable {
    let valid: Bool
    let trackerName: String?
    let trackerId: UUID?

    enum CodingKeys: String, CodingKey {
        case valid
        case trackerName = "tracker_name"
        case trackerId = "tracker_id"
    }
}

final class InviteLinkService {
    private static let inviteLinkBaseURL = "https://cadence.dineshd.dev/invite/"
    private static let expiryDays = 7

    /// Generates a single-use invite link and writes the row to `invite_links`.
    /// Returns the shareable URL.
    func generateInviteLink(trackerUserId: UUID) async throws -> URL {
        let token = UUID().uuidString
        let expiresAt = Calendar.current.date(
            byAdding: .day,
            value: Self.expiryDays,
            to: .now
        ) ?? Date(timeIntervalSinceNow: TimeInterval(Self.expiryDays * 86400))

        let payload = InsertInviteLink(
            trackerUserId: trackerUserId,
            token: token,
            expiresAt: expiresAt
        )

        do {
            try await supabase
                .from("invite_links")
                .insert(payload)
                .execute()
        } catch {
            throw CadenceSupabaseError.from(error)
        }

        guard let url = URL(string: Self.inviteLinkBaseURL + token) else {
            let message = "Failed to construct invite URL from token."
            throw CadenceSupabaseError.unknown(underlying: NSError(
                domain: "InviteLinkService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        }
        return url
    }

    /// Validates an invite token via the `validate_invite_token` RPC.
    /// Returns the tracker's display name on success.
    func validateInviteToken(_ token: String) async throws -> (name: String, trackerId: UUID) {
        do {
            let response: InviteValidationResponse = try await supabase
                .rpc("validate_invite_token", params: ["invite_token": token])
                .execute()
                .value

            guard response.valid,
                  let name = response.trackerName,
                  let trackerId = response.trackerId
            else {
                let message = "This invite link has expired or is no longer valid."
                throw CadenceSupabaseError.unknown(underlying: NSError(
                    domain: "InviteLinkService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: message]
                ))
            }
            return (name: name, trackerId: trackerId)
        } catch let error as CadenceSupabaseError {
            throw error
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }

    /// Accepts an invite atomically via the `accept_invite` RPC.
    /// Creates partner_connections row and marks token as used in one transaction.
    func acceptInvite(token: String, partnerUserId: UUID) async throws {
        do {
            let response: AcceptInviteResponse = try await supabase
                .rpc("accept_invite", params: [
                    "invite_token": AnyJSON.string(token),
                    "accepting_user_id": AnyJSON.string(partnerUserId.uuidString),
                ])
                .execute()
                .value

            guard response.success else {
                let message = response.error ?? "Failed to accept invite."
                throw CadenceSupabaseError.unknown(underlying: NSError(
                    domain: "InviteLinkService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: message]
                ))
            }
        } catch let error as CadenceSupabaseError {
            throw error
        } catch {
            throw CadenceSupabaseError.from(error)
        }
    }
}
