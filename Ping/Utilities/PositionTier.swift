import Foundation

/// Classifies a contact's job title into a seniority tier.
/// Used for both position-targeting and recruiter-focus recommendation modes.
enum PositionTier: String, CaseIterable, Identifiable, Codable, Hashable {
    case executive
    case vp
    case director
    case manager
    case ic
    case recruiter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .executive: return "Executives & Founders"
        case .vp:        return "VPs"
        case .director:  return "Directors"
        case .manager:   return "Managers & Leads"
        case .ic:        return "Individual Contributors"
        case .recruiter: return "Recruiters"
        }
    }

    var systemImage: String {
        switch self {
        case .executive: return "crown"
        case .vp:        return "star"
        case .director:  return "shield"
        case .manager:   return "person.badge.plus"
        case .ic:        return "hammer"
        case .recruiter: return "person.2.badge.gearshape"
        }
    }

    /// Keywords checked (lowercased) against the contact's title via `contains`.
    /// Tiers are checked top-to-bottom; first match wins.
    var keywords: [String] {
        switch self {
        case .executive:
            return ["ceo", "cto", "cfo", "coo", "cpo", "founder", "co-founder", "cofounder",
                    "president", "chairman", "managing partner", "general partner"]
        case .vp:
            return ["vp ", "vice president", " vp", "svp", "evp", "senior vice president"]
        case .director:
            return ["director", "head of", "managing director", "group director"]
        case .manager:
            return ["manager", " lead", "lead ", "principal", "senior manager"]
        case .recruiter:
            return ["recruiter", "talent acquisition", "sourcer", "recruiting", "headhunter",
                    "talent partner", "hiring manager", "people ops", "hr "]
        case .ic:
            return ["engineer", "designer", "analyst", "associate", "coordinator", "specialist",
                    "developer", "scientist", "researcher", "consultant", "advisor", "intern"]
        }
    }

    // MARK: - Classification

    /// Returns the best-matching tier for a contact's title, or nil if unclassifiable.
    /// Iterates tiers in declaration order (executive first, ic last).
    static func classify(title: String?) -> PositionTier? {
        guard let title = title?.lowercased(), !title.isEmpty else { return nil }
        for tier in PositionTier.allCases {
            if tier.keywords.contains(where: { title.contains($0) }) {
                return tier
            }
        }
        return nil
    }

    /// Filters a contact list to only those matching this tier.
    /// Contacts without a title are excluded.
    static func filter(contacts: [Contact], tier: PositionTier) -> [Contact] {
        contacts.filter { classify(title: $0.title) == tier }
    }

    /// Maps a user-facing seniority string (from UserProfile.careerSeniority) to the tier one level above.
    /// Used to personalize the position-target recommendation heuristic.
    static func tierAbove(seniority: String) -> PositionTier? {
        switch seniority.lowercased() {
        case let s where s.contains("student") || s.contains("intern"):
            return .ic
        case let s where s.contains("individual contributor") || s.contains("ic"):
            return .manager
        case let s where s.contains("manager"):
            return .director
        case let s where s.contains("director"):
            return .vp
        case let s where s.contains("vp"):
            return .executive
        default:
            return nil
        }
    }
}
