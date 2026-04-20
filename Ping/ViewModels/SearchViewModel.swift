import Foundation
import Observation

// MARK: - Hybrid result wrapper

/// Wraps a semantic search result with an additional bio-keyword score.
/// Sorting uses a weighted blend: 70% semantic similarity + 30% bio score.
struct RankedSearchResult: Identifiable {
    let result: ContactSearchResult
    /// Score in [0, 1] from BioScorer — 0 if no keyword overlap.
    let bioScore: Float

    var id: UUID { result.id }

    /// Combined score used for display ordering.
    var hybridScore: Float {
        Float(result.similarity) * 0.7 + bioScore * 0.3
    }

    /// True when the bio scorer found a meaningful keyword match.
    var hasBioMatch: Bool { bioScore > 0.6 }
}

// MARK: - ViewModel

@Observable
@MainActor
final class SearchViewModel {
    var query: String = ""
    var searchResults: [RankedSearchResult] = []
    var goals: [Goal] = []
    /// Keyed by goal.id — populated after loadGoals() completes.
    var goalMatches: [UUID: [GoalContactMatch]] = [:]
    /// Full Contact objects for all goal matches, keyed by contact ID. Avoids per-row fetches in the UI.
    var matchedContacts: [UUID: Contact] = [:]
    var isSearching: Bool = false
    var isLoadingGoals: Bool = false
    /// Per-goal loading state — true while match fetch is in flight for that goal.
    var goalMatchLoading: [UUID: Bool] = [:]
    var error: Error? = nil

    private let service = SupabaseService.shared

    // MARK: - Goals

    func loadGoals(contacts: [Contact] = []) async {
        guard let userId = service.currentUserId else { return }
        isLoadingGoals = true
        error = nil
        defer { isLoadingGoals = false }
        do {
            goals = try await service.fetchGoals(userId: userId)
            await loadGoalMatches(userId: userId, contacts: contacts)
            // Batch-fetch full Contact objects for all matched IDs (one query, not N per row).
            let allMatchIds = Array(Set(goalMatches.values.flatMap { $0.map { $0.id } }))
            let fullContacts = (try? await service.fetchContacts(ids: allMatchIds)) ?? []
            matchedContacts = Dictionary(uniqueKeysWithValues: fullContacts.map { ($0.id, $0) })
        } catch {
            self.error = error
        }
    }

    @discardableResult
    func addGoal(text: String) async -> Goal? {
        guard let userId = service.currentUserId else { return nil }
        error = nil
        do {
            let goal = try await service.createGoal(userId: userId, text: text)
            goals.insert(goal, at: 0)
            return goal
        } catch {
            self.error = error
            return nil
        }
    }

    func deactivateGoal(_ goal: Goal) async {
        do {
            try await service.deactivateGoal(id: goal.id)
            goals.removeAll { $0.id == goal.id }
            goalMatches.removeValue(forKey: goal.id)
        } catch {
            self.error = error
        }
    }

    // MARK: - Semantic Search (hybrid)

    /// Searches contacts using a pre-computed embedding from GeminiService,
    /// then re-ranks results by blending semantic similarity with bio keyword score.
    /// - Parameters:
    ///   - embeddedQuery: 768-dim vector from GeminiService.embed(query, .retrievalQuery)
    ///   - contacts: Full contact list from NetworkViewModel for bio scoring (may be empty)
    func searchContacts(embeddedQuery: [Float], contacts: [Contact] = []) async {
        guard let userId = service.currentUserId else { return }
        isSearching = true
        error = nil
        defer { isSearching = false }
        do {
            let semanticResults = try await service.matchContacts(
                queryEmbedding: embeddedQuery,
                userId: userId
            )

            // Build a fast lookup by UUID
            let contactLookup = Dictionary(uniqueKeysWithValues: contacts.map { ($0.id, $0) })

            // Extract meaningful keywords from the current query (reuse BioScorer stop word logic)
            let keywords = query.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }

            // Wrap and score
            let ranked = semanticResults.map { result -> RankedSearchResult in
                let bioScore: Float
                if let fullContact = contactLookup[result.id] {
                    bioScore = BioScorer.score(contact: fullContact, keywords: keywords)
                } else {
                    bioScore = 0
                }
                return RankedSearchResult(result: result, bioScore: bioScore)
            }

            // Sort by hybrid score descending
            searchResults = ranked.sorted { $0.hybridScore > $1.hybridScore }
        } catch {
            self.error = error
        }
    }

    // MARK: - Private

    private func loadGoalMatches(userId: UUID, contacts: [Contact]) async {
        // Mark all active goals as loading before kicking off tasks.
        for goal in goals where goal.active {
            goalMatchLoading[goal.id] = true
        }

        // Build contact lookup for bio re-ranking
        let contactLookup = Dictionary(uniqueKeysWithValues: contacts.map { ($0.id, $0) })

        await withTaskGroup(of: (UUID, [GoalContactMatch]).self) { group in
            for goal in goals where goal.active {
                group.addTask { [service] in
                    // Fetch more candidates so bio re-ranking has room to work
                    let matches = (try? await service.matchContactsForGoal(
                        goalId: goal.id,
                        userId: userId,
                        count: 15
                    )) ?? []

                    // Re-rank: blend semantic similarity with bio score from goal keywords
                    guard !contacts.isEmpty else { return (goal.id, matches) }
                    let keywords = goal.text.lowercased()
                        .components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }

                    let reranked = matches
                        .map { match -> (GoalContactMatch, Float) in
                            let bioScore = contactLookup[match.id].map {
                                BioScorer.score(contact: $0, keywords: keywords)
                            } ?? 0
                            let hybrid = Float(match.similarity) * 0.65 + bioScore * 0.35
                            return (match, hybrid)
                        }
                        .sorted { $0.1 > $1.1 }
                        .map { $0.0 }

                    return (goal.id, reranked)
                }
            }
            for await (goalId, matches) in group {
                goalMatches[goalId] = matches
                goalMatchLoading[goalId] = false
            }
        }
    }
}
