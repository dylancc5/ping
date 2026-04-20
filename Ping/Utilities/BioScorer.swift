import Foundation

/// Scores a contact against a set of keywords by checking structured bio fields.
/// All scoring is in-memory — no network calls, no embeddings.
struct BioScorer {

    // MARK: - Field weights (higher = more signal)

    private enum Weight {
        static let title:   Float = 2.0
        static let company: Float = 1.5
        static let tags:    Float = 2.0
        static let notes:   Float = 1.0
        static let howMet:  Float = 0.5
        static let total: Float = title + company + tags + notes + howMet
    }

    // MARK: - Public API

    /// Returns a score in [0, 1] representing how well the contact's bio matches the keywords.
    /// 0 = no matches, 1 = saturated match across all high-weight fields.
    static func score(contact: Contact, keywords: [String]) -> Float {
        guard !keywords.isEmpty else { return 0 }
        let kws = keywords.map { $0.lowercased() }.filter { !$0.isEmpty && !stopWords.contains($0) }
        guard !kws.isEmpty else { return 0 }

        var accumulated: Float = 0

        // Title — full weight for any keyword hit
        if let title = contact.title?.lowercased(), !title.isEmpty {
            if kws.contains(where: { title.contains($0) }) {
                accumulated += Weight.title
            }
        }

        // Company — full weight for any keyword hit
        if let company = contact.company?.lowercased(), !company.isEmpty {
            if kws.contains(where: { company.contains($0) }) {
                accumulated += Weight.company
            }
        }

        // Tags — exact lowercased match per keyword, fractional accumulation
        if !contact.tags.isEmpty {
            let tagSet = Set(contact.tags.map { $0.lowercased() })
            let tagHits = kws.filter { tagSet.contains($0) }.count
            if tagHits > 0 {
                let fraction = Float(min(tagHits, contact.tags.count)) / Float(max(kws.count, 1))
                accumulated += Weight.tags * min(fraction, 1.0)
            }
        }

        // Notes — substring match, half weight (loose signal)
        if let notes = contact.notes?.lowercased(), !notes.isEmpty {
            let noteHits = kws.filter { notes.contains($0) }.count
            if noteHits > 0 {
                accumulated += Weight.notes * 0.5
            }
        }

        // How met — substring match, low weight
        let howMet = contact.howMet.lowercased()
        if kws.contains(where: { howMet.contains($0) }) {
            accumulated += Weight.howMet
        }

        return min(accumulated / Weight.total, 1.0)
    }

    /// Scores and ranks a contact list against keywords. Returns descending order, score > 0 only.
    static func rank(contacts: [Contact], keywords: [String]) -> [(contact: Contact, score: Float)] {
        contacts
            .map { ($0, score(contact: $0, keywords: keywords)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    // MARK: - Stop words (skip these when tokenizing search queries)

    private static let stopWords: Set<String> = [
        "a", "an", "the", "and", "or", "of", "in", "at", "to", "for",
        "is", "are", "was", "be", "do", "i", "my", "me", "who", "what",
        "know", "with", "from", "on", "by", "this", "that", "it", "as"
    ]
}
