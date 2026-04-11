import Foundation

enum NudgeStatus: String, Codable, Sendable {
    case pending   = "pending"
    case delivered = "delivered"
    case opened    = "opened"
    case acted     = "acted"
    case snoozed   = "snoozed"
    case dismissed = "dismissed"
}

struct Nudge: Identifiable, Codable, Sendable {
    let id: UUID
    let contactId: UUID
    let userId: UUID
    var status: NudgeStatus
    var reason: String?
    var draftMessage: String?
    var scheduledAt: Date
    var deliveredAt: Date?
    var actedAt: Date?
    var snoozedUntil: Date?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status, reason
        case contactId    = "contact_id"
        case userId       = "user_id"
        case draftMessage = "draft_message"
        case scheduledAt  = "scheduled_at"
        case deliveredAt  = "delivered_at"
        case actedAt      = "acted_at"
        case snoozedUntil = "snoozed_until"
        case createdAt    = "created_at"
    }
}
