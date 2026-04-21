import Foundation
import Observation

@Observable
@MainActor
final class PingViewModel {
    var pendingNudges: [Nudge] = []
    var snoozedNudges: [Nudge] = []
    /// Contacts with warmth_score < 0.5 that haven't been contacted in over a week.
    var coolingContacts: [Contact] = []
    /// Full contact lookup by ID — used to resolve contacts for nudge cards.
    var contacts: [UUID: Contact] = [:]
    var isLoading: Bool = false
    var error: Error? = nil

    private let service = SupabaseService.shared

    private var coolingWarmthThreshold: Double { RemoteConfigService.shared.config.coolingWarmthThreshold }
    private var coolingIdleInterval: TimeInterval { RemoteConfigService.shared.config.coolingIdleDays * 24 * 3_600 }

    func load() async {
        guard let userId = service.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        async let nudgesFetch   = service.fetchActiveNudges(userId: userId)
        async let snoozedFetch  = service.fetchSnoozedNudges(userId: userId)
        async let contactsFetch = service.fetchContacts(userId: userId)
        do {
            let (nudges, snoozed, allContacts) = try await (nudgesFetch, snoozedFetch, contactsFetch)
            pendingNudges   = nudges
            contacts        = Dictionary(uniqueKeysWithValues: allContacts.map { ($0.id, $0) })
            coolingContacts = allContacts.filter(isCooling)

            // Auto-unsnooze: move expired snoozed nudges back to pending.
            // If the DB write fails, keep the nudge snoozed to avoid a state split.
            let now = Date()
            var stillSnoozed: [Nudge] = []
            for var nudge in snoozed {
                if let until = nudge.snoozedUntil, until <= now {
                    do {
                        try await service.updateNudgeStatus(id: nudge.id, status: .pending)
                        nudge.status = .pending
                        pendingNudges.append(nudge)
                    } catch {
                        stillSnoozed.append(nudge)
                    }
                } else {
                    stillSnoozed.append(nudge)
                }
            }
            snoozedNudges = stillSnoozed
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

    /// Generates AI drafts for any pending nudges that don't have one yet,
    /// updating in-memory state as each draft completes and persisting to Supabase.
    func generateMissingDrafts() async {
        guard let userId = service.currentUserId else { return }
        let needsDraft = pendingNudges.filter { $0.draftMessage == nil || $0.draftMessage!.isEmpty }
        guard !needsDraft.isEmpty else { return }

        let toneSamples = (try? await service.fetchToneSamples(userId: userId)) ?? []

        await withTaskGroup(of: (UUID, String?).self) { group in
            for nudge in needsDraft {
                guard let contact = contacts[nudge.contactId] else { continue }
                let reason = nudge.reason ?? "General check-in"
                group.addTask {
                    let draft = try? await GeminiService.generateDraft(
                        contact: contact,
                        nudgeReason: reason,
                        toneSamples: toneSamples
                    )
                    return (nudge.id, draft)
                }
            }
            for await (nudgeId, draft) in group {
                guard let draft, !draft.isEmpty else { continue }
                if let idx = pendingNudges.firstIndex(where: { $0.id == nudgeId }) {
                    pendingNudges[idx].draftMessage = draft
                }
                try? await service.updateNudgeDraft(id: nudgeId, draftMessage: draft)
            }
        }
    }

    func unsnoozeNudge(_ nudge: Nudge) async {
        do {
            try await service.updateNudgeStatus(id: nudge.id, status: .pending)
            snoozedNudges.removeAll { $0.id == nudge.id }
            var reactivated = nudge
            reactivated.status = .pending
            pendingNudges.append(reactivated)
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
        guard contact.warmthScore < coolingWarmthThreshold else { return false }
        guard let lastContacted = contact.lastContactedAt else { return true }
        return Date().timeIntervalSince(lastContacted) > coolingIdleInterval
    }
}
