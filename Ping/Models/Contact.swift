import Foundation

struct Contact: Identifiable, Codable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var company: String?
    var title: String?
    var howMet: String
    var notes: String?
    var linkedinUrl: String?
    var email: String?
    var phone: String?
    var tags: [String]
    var warmthScore: Double
    var lastContactedAt: Date?
    var metAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case id, name, company, title, notes, email, phone, tags
        case userId          = "user_id"
        case howMet          = "how_met"
        case linkedinUrl     = "linkedin_url"
        case warmthScore     = "warmth_score"
        case lastContactedAt = "last_contacted_at"
        case metAt           = "met_at"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
        // `embedding` intentionally absent — pgvector returns a raw vector string;
        // iOS only writes embeddings, never decodes them
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,   forKey: .id)
        userId          = try c.decode(UUID.self,   forKey: .userId)
        name            = try c.decode(String.self, forKey: .name)
        company         = try c.decodeIfPresent(String.self, forKey: .company)
        title           = try c.decodeIfPresent(String.self, forKey: .title)
        howMet          = try c.decode(String.self, forKey: .howMet)
        notes           = try c.decodeIfPresent(String.self, forKey: .notes)
        linkedinUrl     = try c.decodeIfPresent(String.self, forKey: .linkedinUrl)
        email           = try c.decodeIfPresent(String.self, forKey: .email)
        phone           = try c.decodeIfPresent(String.self, forKey: .phone)
        tags            = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        warmthScore     = try c.decodeIfPresent(Double.self, forKey: .warmthScore) ?? 1.0
        lastContactedAt = try c.decodeIfPresent(Date.self, forKey: .lastContactedAt)
        metAt           = try c.decodeIfPresent(Date.self, forKey: .metAt)
        createdAt       = try c.decode(Date.self, forKey: .createdAt)
        updatedAt       = try c.decode(Date.self, forKey: .updatedAt)
    }
}

extension Contact {
    static let preview = Contact(
        id: UUID(), userId: UUID(),
        name: "Marcus Chen", company: "Google", title: "PM",
        howMet: "SCET career fair", notes: "Interested in ML infra",
        linkedinUrl: nil, email: nil, phone: nil,
        tags: ["ML", "Google"], warmthScore: 0.9,
        lastContactedAt: Calendar.current.date(byAdding: .day, value: -9, to: Date()),
        metAt: Date(), createdAt: Date(), updatedAt: Date()
    )

    static let previewCold = Contact(
        id: UUID(), userId: UUID(),
        name: "Sarah Kim", company: "Stripe", title: "PM",
        howMet: "Cal Hacks", notes: nil,
        linkedinUrl: nil, email: nil, phone: nil,
        tags: [], warmthScore: 0.15,
        lastContactedAt: Calendar.current.date(byAdding: .weekOfYear, value: -8, to: Date()),
        metAt: Date(), createdAt: Date(), updatedAt: Date()
    )

    // Memberwise init for previews and local construction
    init(
        id: UUID, userId: UUID,
        name: String, company: String? = nil, title: String? = nil,
        howMet: String, notes: String? = nil,
        linkedinUrl: String? = nil, email: String? = nil, phone: String? = nil,
        tags: [String] = [], warmthScore: Double = 1.0,
        lastContactedAt: Date? = nil, metAt: Date? = nil,
        createdAt: Date, updatedAt: Date
    ) {
        self.id = id; self.userId = userId
        self.name = name; self.company = company; self.title = title
        self.howMet = howMet; self.notes = notes
        self.linkedinUrl = linkedinUrl; self.email = email; self.phone = phone
        self.tags = tags; self.warmthScore = warmthScore
        self.lastContactedAt = lastContactedAt; self.metAt = metAt
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}
