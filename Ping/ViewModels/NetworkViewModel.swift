import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class NetworkViewModel {
    var contacts: [Contact] = []
    var isLoading: Bool = false
    var error: Error? = nil

    /// Contacts sorted by warmth descending — mirrors the DB query order but
    /// stays live after local optimistic inserts/deletes.
    var sortedContacts: [Contact] {
        contacts.sorted { $0.warmthScore > $1.warmthScore }
    }

    private let service = SupabaseService.shared

    func loadContacts() async {
        guard let userId = await service.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            contacts = try await service.fetchContacts(userId: userId)
        } catch {
            self.error = error
        }
    }

    func createContact(_ draft: ContactDraft) async {
        guard draft.isValid else { return }
        guard let userId = await service.currentUserId else { return }
        let payload = ContactInsertPayload(draft: draft, userId: userId)
        do {
            let created = try await service.createContact(payload: payload)
            contacts.insert(created, at: 0)
            Task {
                let text = "\(created.name), \(created.title ?? "") at \(created.company ?? ""). Met at \(created.howMet). Notes: \(created.notes ?? ""). Tags: \(created.tags.joined(separator: ", "))"
                if let embedding = try? await GeminiService.embed(text, taskType: .retrievalDocument) {
                    try? await service.updateContactEmbedding(id: created.id, embeddingString: embedding.pgVectorLiteral)
                }
            }
        } catch {
            self.error = error
        }
    }

    func updateContact(id: UUID, fields: [String: AnyJSON]) async {
        do {
            try await service.updateContact(id: id, fields: fields)
            // Reload the single contact to reflect server-side changes (e.g. updated_at).
            let updated = try await service.fetchContact(id: id)
            if let idx = contacts.firstIndex(where: { $0.id == id }) {
                contacts[idx] = updated
            }
        } catch {
            self.error = error
        }
    }

    func deleteContact(_ contact: Contact) async {
        do {
            try await service.deleteContact(id: contact.id)
            contacts.removeAll { $0.id == contact.id }
        } catch {
            self.error = error
        }
    }
}
