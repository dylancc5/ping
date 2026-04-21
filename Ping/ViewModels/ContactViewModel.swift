import Foundation
import Observation

@Observable
@MainActor
final class ContactViewModel {
    var contact: Contact? = nil
    var interactions: [Interaction] = []
    var nudges: [Nudge] = []
    var isLoading: Bool = false
    var error: Error? = nil

    /// Draft message text, populated from a nudge's draftMessage or entered by the user.
    var messageDraft: String = ""

    /// AI-generated draft cached in-memory for the session. Populates messageDraft on load.
    var cachedDraft: String? = nil

    private let service = SupabaseService.shared

    // MARK: - Loading

    func load(contactId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        async let contactFetch      = service.fetchContact(id: contactId)
        async let interactionsFetch = service.fetchInteractions(contactId: contactId)
        async let nudgesFetch       = service.fetchNudges(contactId: contactId)
        do {
            let (c, i, n) = try await (contactFetch, interactionsFetch, nudgesFetch)
            contact      = c
            interactions = i
            nudges       = n
        } catch {
            self.error = error
            return
        }
        if let c = contact {
            _ = await generateDraft(contact: c, nudgeReason: nudges.first?.reason ?? "General check-in")
        }
    }

    // MARK: - Interactions

    func logInteraction(type: InteractionType, notes: String? = nil) async {
        guard let contact, let userId = service.currentUserId else { return }
        let interaction = Interaction(
            id: UUID(),
            contactId: contact.id,
            userId: userId,
            type: type,
            notes: notes,
            occurredAt: Date(),
            createdAt: Date()
        )
        do {
            let saved = try await service.createInteraction(interaction)
            interactions.insert(saved, at: 0)
            // Reset warmth score so this contact doesn't continue to decay into obscurity
            let now = ISO8601DateFormatter().string(from: Date())
            try await service.updateContact(id: contact.id, fields: [
                "warmth_score": .double(1.0),
                "last_contacted_at": .string(now)
            ])
            self.contact?.warmthScore = 1.0
            self.contact?.lastContactedAt = Date()
        } catch {
            self.error = error
        }
    }

    // MARK: - Nudges

    func saveNudgeDraft(_ nudge: Nudge, draft: String) async {
        do {
            try await service.updateNudgeDraft(id: nudge.id, draftMessage: draft)
            if let idx = nudges.firstIndex(where: { $0.id == nudge.id }) {
                nudges[idx].draftMessage = draft
            }
        } catch {
            self.error = error
        }
    }

    func dismissNudge(_ nudge: Nudge) async {
        do {
            try await service.updateNudgeStatus(id: nudge.id, status: .dismissed)
            if let idx = nudges.firstIndex(where: { $0.id == nudge.id }) {
                nudges[idx].status = .dismissed
            }
        } catch {
            self.error = error
        }
    }

    // MARK: - Draft Generation

    @discardableResult
    func generateDraft(contact: Contact, nudgeReason: String, forceRefresh: Bool = false, tone: DraftTone? = nil) async -> String? {
        if !forceRefresh, tone == nil, let cachedDraft, !cachedDraft.isEmpty {
            if messageDraft.isEmpty { messageDraft = cachedDraft }
            return cachedDraft
        }

        guard let userId = service.currentUserId else { return nil }
        let toneSamples = (try? await service.fetchToneSamples(userId: userId)) ?? []
        do {
            let draft = try await HFService.generateDraft(
                contact: contact,
                nudgeReason: nudgeReason,
                toneSamples: toneSamples,
                tone: tone
            )
            cachedDraft = draft
            if messageDraft.isEmpty || forceRefresh { messageDraft = draft }
            return draft
        } catch {
            self.error = error
            return nil
        }
    }
}
