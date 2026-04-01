import Foundation

struct CadenceUser: Codable, Identifiable {
    let id: UUID
    let email: String
    let displayName: String
    let isTracker: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case isTracker = "is_tracker"
        case createdAt = "created_at"
    }
}
