import Foundation

enum InteractionType: String, Codable, Sendable {
    case met         = "met"
    case message     = "message"
    case call        = "call"
    case note        = "note"
    case nudgeSent   = "nudge_sent"

    var icon: String {
        switch self {
        case .met:       return "person.badge.plus"
        case .message:   return "message.fill"
        case .call:      return "phone.fill"
        case .note:      return "note.text"
        case .nudgeSent: return "bell.fill"
        }
    }

    var label: String {
        switch self {
        case .met:       return "Met"
        case .message:   return "Message"
        case .call:      return "Call"
        case .note:      return "Note"
        case .nudgeSent: return "Nudge Sent"
        }
    }
}

struct Interaction: Identifiable, Codable, Sendable {
    let id: UUID
    let contactId: UUID
    let userId: UUID
    var type: InteractionType
    var notes: String?
    var occurredAt: Date
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, notes
        case contactId  = "contact_id"
        case userId     = "user_id"
        case occurredAt = "occurred_at"
        case createdAt  = "created_at"
    }
}
