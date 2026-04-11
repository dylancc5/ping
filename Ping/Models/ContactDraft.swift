import Foundation

/// Intermediate struct used during contact capture (voice/text) and import flows.
/// Not Codable — has no id or userId. Convert to `ContactInsertPayload` before sending to Supabase.
struct ContactDraft: Sendable {
    var name: String = ""
    var company: String? = nil
    var title: String? = nil
    var howMet: String = ""
    var notes: String? = nil
    var linkedinUrl: String? = nil
    var email: String? = nil
    var phone: String? = nil
    var tags: [String] = []
    var metAt: Date? = nil

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !howMet.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Suggested contact from a Google Calendar meeting.
struct CalendarSuggestion: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let email: String
    let eventTitle: String
    let eventDate: Date
}

/// Suggested contact from Gmail sent-mail frequency analysis.
struct ContactSuggestion: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let email: String
    let frequency: Int
}

/// Encodable payload sent to Supabase when inserting a new contact.
/// Produced from a validated `ContactDraft` + authenticated userId.
struct ContactInsertPayload: Encodable {
    let userId: UUID
    let name: String
    let company: String?
    let title: String?
    let howMet: String
    let notes: String?
    let linkedinUrl: String?
    let email: String?
    let phone: String?
    let tags: [String]
    let metAt: Date?

    enum CodingKeys: String, CodingKey {
        case name, company, title, notes, email, phone, tags
        case userId      = "user_id"
        case howMet      = "how_met"
        case linkedinUrl = "linkedin_url"
        case metAt       = "met_at"
    }

    init(draft: ContactDraft, userId: UUID) {
        self.userId      = userId
        self.name        = draft.name
        self.company     = draft.company
        self.title       = draft.title
        self.howMet      = draft.howMet
        self.notes       = draft.notes
        self.linkedinUrl = draft.linkedinUrl
        self.email       = draft.email
        self.phone       = draft.phone
        self.tags        = draft.tags
        self.metAt       = draft.metAt
    }
}
