import Foundation
import Observation

@Observable
@MainActor
final class PingViewModel {
    var pendingNudges: [Nudge] = []
    /// Contacts with warmth_score < 0.5 that haven't been contacted in over a week.
    var coolingContacts: [Contact] = []
    /// Full contact lookup by ID — used to resolve contacts for nudge cards.
    var contacts: [UUID: Contact] = [:]
    var isLoading: Bool = false
    var error: Error? = nil

    private let service = SupabaseService.shared

    private static let coolingWarmthThreshold: Double = 0.5
    private static let coolingIdleInterval: TimeInterval = 7 * 24 * 3_600 // 1 week

    func load() async {
        guard let userId = await service.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        async let nudgesFetch   = service.fetchPendingNudges(userId: userId)
        async let contactsFetch = service.fetchContacts(userId: userId)
        do {
            let (nudges, allContacts) = try await (nudgesFetch, contactsFetch)
            pendingNudges   = nudges
            contacts        = Dictionary(uniqueKeysWithValues: allContacts.map { ($0.id, $0) })
            coolingContacts = allContacts.filter(isCooling)
        } catch {
            self.error = error
        }
    }

    func dismissNudge(_ nudge: Nudge) async {
        do {
            try await service.updateNudgeStatus(id: nudge.id, status: .dismissed)
            pendingNudges.removeAll { $0.id == nudge.id }
        } catch {
            self.error = error
        }
    }

    func snoozeNudge(_ nudge: Nudge, until date: Date) async {
        do {
            try await service.updateNudgeStatus(id: nudge.id, status: .snoozed, snoozedUntil: date)
            pendingNudges.removeAll { $0.id == nudge.id }
        } catch {
            self.error = error
        }
    }

    func markNudgeActed(_ nudge: Nudge) async {
        do {
            try await service.updateNudgeStatus(id: nudge.id, status: .acted)
            pendingNudges.removeAll { $0.id == nudge.id }
        } catch {
            self.error = error
        }
    }

    private func isCooling(_ contact: Contact) -> Bool {
        guard contact.warmthScore < Self.coolingWarmthThreshold else { return false }
        guard let lastContacted = contact.lastContactedAt else { return true }
        return Date().timeIntervalSince(lastContacted) > Self.coolingIdleInterval
    }
}
