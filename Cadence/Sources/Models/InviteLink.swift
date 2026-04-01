import Foundation

struct InviteLink: Codable, Identifiable {
    let id: UUID
    let trackerUserId: UUID
    let token: String
    let expiresAt: Date
    let used: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case trackerUserId = "tracker_user_id"
        case token
        case expiresAt = "expires_at"
        case used
    }
}
