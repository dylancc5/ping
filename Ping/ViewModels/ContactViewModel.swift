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
        Task {
            if let c = contact,
               let draft = try? await GeminiService.generateDraft(
                   contact: c,
                   nudgeReason: nudges.first?.reason ?? "General check-in",
                   toneSamples: []  // Phase 3: load from profiles table
               ) {
                cachedDraft = draft
                if messageDraft.isEmpty { messageDraft = draft }
            }
        }
    }

    // MARK: - Interactions

    func logInteraction(type: InteractionType, notes: String? = nil) async {
        guard let contact, let userId = await service.currentUserId else { return }
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
}
