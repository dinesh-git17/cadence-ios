import Foundation

enum ConnectionStatus: String, Codable {
    case active
    case inactive
}

struct PartnerConnection: Codable, Identifiable {
    let id: UUID
    let trackerUserId: UUID
    let partnerUserId: UUID
    let connectedAt: Date
    let status: ConnectionStatus

    enum CodingKeys: String, CodingKey {
        case id
        case trackerUserId = "tracker_user_id"
        case partnerUserId = "partner_user_id"
        case connectedAt = "connected_at"
        case status
    }
}
