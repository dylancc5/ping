import Foundation

// MARK: - Shared Attribute

enum SharedAttribute: Equatable {
    case sameCompany(String)
    case sharedTag(String)
    case sharedHowMet(String)           // first 2 words of howMet match
    case sharedIndustryKeyword(String)  // matched from predefined vocabulary
}

// MARK: - Result

struct CommonalityResult: Identifiable {
    let id: UUID  // contact.id
    let contact: Contact
    let sharedAttributes: [SharedAttribute]

    /// The most prominent shared attribute, formatted as a human-readable label.
    var primaryLabel: String {
        guard let first = sharedAttributes.first else { return "" }
        switch first {
        case .sameCompany(let name):          return "Both at \(name)"
        case .sharedTag(let tag):             return "Both tagged \(tag)"
        case .sharedHowMet(let context):      return "Both met at \(context)"
        case .sharedIndustryKeyword(let kw):  return "Both in \(kw)"
        }
    }
}

// MARK: - Matcher

struct CommonalityMatcher {

    // MARK: - Public API

    /// Finds contacts that share attributes with a pivot contact.
    /// The pivot itself is excluded from results.
    static func findCommon(among contacts: [Contact], comparedTo pivot: Contact) -> [CommonalityResult] {
        contacts
            .filter { $0.id != pivot.id }
            .compactMap { candidate -> CommonalityResult? in
                let attrs = sharedAttributes(between: pivot, and: candidate)
                guard !attrs.isEmpty else { return nil }
                return CommonalityResult(id: candidate.id, contact: candidate, sharedAttributes: attrs)
            }
            .sorted { $0.sharedAttributes.count > $1.sharedAttributes.count }
    }

    /// Without a pivot, finds the contacts that share the most attributes with anyone else
    /// in the network. Useful for surfacing "your most connected" contacts.
    /// Returns up to `limit` results.
    static func topResults(contacts: [Contact], limit: Int = 10) -> [CommonalityResult] {
        guard contacts.count > 1 else { return [] }

        var scoreMap: [UUID: (contact: Contact, attrs: [SharedAttribute], count: Int)] = [:]

        for i in contacts.indices {
            for j in contacts.indices where j > i {
                let a = contacts[i]
                let b = contacts[j]
                let attrs = sharedAttributes(between: a, and: b)
                guard !attrs.isEmpty else { continue }

                // Credit both sides
                scoreMap[a.id, default: (a, [], 0)].attrs = mergeUnique(scoreMap[a.id]?.attrs ?? [], attrs)
                scoreMap[a.id, default: (a, [], 0)].count += attrs.count
                scoreMap[b.id, default: (b, [], 0)].attrs = mergeUnique(scoreMap[b.id]?.attrs ?? [], attrs)
                scoreMap[b.id, default: (b, [], 0)].count += attrs.count
            }
        }

        return scoreMap.values
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { CommonalityResult(id: $0.contact.id, contact: $0.contact, sharedAttributes: $0.attrs) }
    }

    // MARK: - Private

    private static func sharedAttributes(between a: Contact, and b: Contact) -> [SharedAttribute] {
        var attrs: [SharedAttribute] = []

        // Same company (non-empty, case-insensitive)
        if let ca = a.company?.lowercased().trimmingCharacters(in: .whitespaces),
           let cb = b.company?.lowercased().trimmingCharacters(in: .whitespaces),
           !ca.isEmpty, ca == cb {
            attrs.append(.sameCompany(a.company!))
        }

        // Shared tags (exact lowercased intersection)
        let tagsA = Set(a.tags.map { $0.lowercased() })
        let tagsB = Set(b.tags.map { $0.lowercased() })
        let commonTags = tagsA.intersection(tagsB)
        for tag in commonTags.sorted() {
            // Use original casing from a
            let original = a.tags.first { $0.lowercased() == tag } ?? tag
            attrs.append(.sharedTag(original))
        }

        // Shared "how met" context (first 2 significant words match)
        let prefixA = howMetPrefix(a.howMet)
        let prefixB = howMetPrefix(b.howMet)
        if !prefixA.isEmpty, prefixA == prefixB {
            attrs.append(.sharedHowMet(prefixA))
        }

        // Shared industry keyword (from notes + title)
        let textA = [(a.title ?? ""), (a.notes ?? "")].joined(separator: " ").lowercased()
        let textB = [(b.title ?? ""), (b.notes ?? "")].joined(separator: " ").lowercased()
        for kw in industryKeywords {
            if textA.contains(kw) && textB.contains(kw) {
                attrs.append(.sharedIndustryKeyword(kw.capitalized))
                break  // one industry keyword per pair is enough
            }
        }

        return attrs
    }

    /// Extracts the first 2 significant words from a "how met" string for fuzzy context matching.
    private static func howMetPrefix(_ text: String) -> String {
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && !prefixStopWords.contains($0) }
        return words.prefix(2).joined(separator: " ")
    }

    private static func mergeUnique(_ existing: [SharedAttribute], _ new: [SharedAttribute]) -> [SharedAttribute] {
        var result = existing
        for attr in new where !result.contains(attr) {
            result.append(attr)
        }
        return result
    }

    // MARK: - Vocabularies

    private static let prefixStopWords: Set<String> = ["at", "the", "a", "an", "in", "at", "via", "through", "met"]

    private static let industryKeywords: [String] = [
        "fintech", "healthtech", "health tech", "biotech", "edtech",
        "climate", "cleantech", "crypto", "web3", "defi",
        "saas", "enterprise", "b2b", "b2c",
        "venture", "vc", "private equity",
        "ai", "machine learning", "ml", "artificial intelligence",
        "media", "consulting", "defense", "government", "nonprofit",
        "e-commerce", "ecommerce", "logistics", "real estate", "proptech"
    ]
}
