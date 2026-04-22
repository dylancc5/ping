import Foundation
import Observation

// MARK: - Result type

struct RecommendationResult: Identifiable {
    let id: UUID  // contact.id
    let contact: Contact
    let mode: RecommendationMode
    let label: String   // e.g. "Recruiter at Stripe", "Both at YC Demo Day", "VP · Meta"
    let score: Float    // higher = stronger recommendation
}

// MARK: - ViewModel

@Observable
@MainActor
final class RecommendationViewModel {

    var filter: RecommendationFilter
    var results: [RecommendationResult] = []
    var isComputing: Bool = false

    init() {
        self.filter = RecommendationFilter.load()
    }

    // MARK: - Public

    func compute(contacts: [Contact], userProfile: UserProfile = UserProfile()) async {
        guard !contacts.isEmpty else {
            results = []
            return
        }
        isComputing = true
        defer { isComputing = false }

        var all: [RecommendationResult] = []

        if filter.enabledModes.contains(.thingsInCommon) {
            all += applyThingsInCommon(contacts: contacts)
            // Blend in user-profile-aware matches when the profile has content
            if userProfile.hasContent {
                all += applyUserProfileMatches(contacts: contacts, profile: userProfile)
            }
        }
        if filter.enabledModes.contains(.positionTarget) {
            all += applyPositionTarget(contacts: contacts, userProfile: userProfile)
        }
        if filter.enabledModes.contains(.recruiterFocus) {
            all += applyRecruiterFocus(contacts: contacts)
        }

        // Dedupe: keep one result per contact (highest score wins)
        var seen: Set<UUID> = []
        var deduped: [RecommendationResult] = []
        for result in all.sorted(by: { $0.score > $1.score }) {
            if seen.insert(result.id).inserted {
                deduped.append(result)
            }
        }

        results = deduped
    }

    func saveFilter() {
        filter.save()
    }

    // MARK: - Private Pipelines

    private func applyThingsInCommon(contacts: [Contact]) -> [RecommendationResult] {
        let commonResults = CommonalityMatcher.topResults(contacts: contacts, limit: 8)
        return commonResults.map { cr in
            let score = Float(cr.sharedAttributes.count) / 4.0  // 4 attrs = score of 1.0
            return RecommendationResult(
                id: cr.id,
                contact: cr.contact,
                mode: .thingsInCommon,
                label: cr.primaryLabel,
                score: min(score, 1.0)
            )
        }
    }

    private func applyUserProfileMatches(contacts: [Contact], profile: UserProfile) -> [RecommendationResult] {
        CommonalityMatcher.matchedForUser(contacts: contacts, profile: profile, limit: 5).map { cr in
            let score = Float(cr.sharedAttributes.count) / 3.0
            return RecommendationResult(
                id: cr.id,
                contact: cr.contact,
                mode: .thingsInCommon,
                label: cr.primaryLabel,
                score: min(score, 1.0)
            )
        }
    }

    private func applyPositionTarget(contacts: [Contact], userProfile: UserProfile = UserProfile()) -> [RecommendationResult] {
        // If the user has filled in their seniority, use it to anchor the "one tier above" heuristic.
        var tiers = filter.targetTiers.isEmpty ? [PositionTier.executive, .vp] : Array(filter.targetTiers)
        if !userProfile.careerSeniority.isNilOrEmpty, let oneTierAbove = PositionTier.tierAbove(seniority: userProfile.careerSeniority!) {
            // Prepend the personalized tier so it gets priority in dedup
            tiers = [oneTierAbove] + tiers.filter { $0 != oneTierAbove }
        }
        let tiers2 = tiers
        var results: [RecommendationResult] = []
        for tier in tiers2 {
            let matched = PositionTier.filter(contacts: contacts, tier: tier)
                .sorted { $0.warmthScore > $1.warmthScore }
                .prefix(5)
            for contact in matched {
                let companyPart = contact.company.map { " · \($0)" } ?? ""
                let label = "\(tier.displayName)\(companyPart)"
                results.append(RecommendationResult(
                    id: contact.id,
                    contact: contact,
                    mode: .positionTarget,
                    label: label,
                    score: Float(contact.warmthScore)
                ))
            }
        }
        return results
    }

    private func applyRecruiterFocus(contacts: [Contact]) -> [RecommendationResult] {
        // Recruiters sorted by least recently contacted first (most overdue)
        PositionTier.filter(contacts: contacts, tier: .recruiter)
            .sorted { a, b in
                // nil last_contacted (never reached out) = highest priority
                switch (a.lastContactedAt, b.lastContactedAt) {
                case (nil, nil):    return false
                case (nil, _):     return true
                case (_, nil):     return false
                case (let la, let lb): return la! < lb!
                }
            }
            .prefix(6)
            .map { contact in
                let companyPart = contact.company.map { " at \($0)" } ?? ""
                let label = "Recruiter\(companyPart)"
                return RecommendationResult(
                    id: contact.id,
                    contact: contact,
                    mode: .recruiterFocus,
                    label: label,
                    score: 1.0 - Float(contact.warmthScore)  // cold recruiters surface first
                )
            }
    }
}
