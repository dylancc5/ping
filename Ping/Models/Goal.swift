import Foundation

struct Goal: Identifiable, Codable, Sendable {
    let id: UUID
    let userId: UUID
    var text: String
    var active: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, text, active
        case userId    = "user_id"
        case createdAt = "created_at"
        // `embedding` intentionally absent — same write-only pattern as Contact
    }
}
