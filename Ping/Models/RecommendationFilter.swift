import Foundation

// MARK: - Recommendation Mode

enum RecommendationMode: String, CaseIterable, Identifiable, Codable, Hashable {
    case thingsInCommon
    case positionTarget
    case recruiterFocus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thingsInCommon:  return "Things in Common"
        case .positionTarget:  return "By Position"
        case .recruiterFocus:  return "Recruiters"
        }
    }

    var systemImage: String {
        switch self {
        case .thingsInCommon:  return "person.2.fill"
        case .positionTarget:  return "chart.bar.fill"
        case .recruiterFocus:  return "person.badge.plus"
        }
    }

    var description: String {
        switch self {
        case .thingsInCommon:
            return "Contacts who share your background, industry, or how you met"
        case .positionTarget:
            return "Contacts at specific seniority levels in your network"
        case .recruiterFocus:
            return "Recruiters and talent partners in your network"
        }
    }
}

// MARK: - Recommendation Filter

struct RecommendationFilter: Codable {
    var enabledModes: Set<RecommendationMode>
    /// Target tiers — used when `.positionTarget` mode is active.
    var targetTiers: Set<PositionTier>

    static var `default`: RecommendationFilter {
        RecommendationFilter(
            enabledModes: [.thingsInCommon, .recruiterFocus],
            targetTiers: [.executive, .vp]
        )
    }

    // MARK: - UserDefaults persistence

    private static let defaultsKey = "ping.recommendationFilter"

    static func load() -> RecommendationFilter {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let filter = try? JSONDecoder().decode(RecommendationFilter.self, from: data)
        else { return .default }
        return filter
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: RecommendationFilter.defaultsKey)
    }
}
