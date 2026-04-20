import Foundation
import Observation
import Supabase

enum ContactSortOrder: String, CaseIterable {
    case recency = "Recent"
    case warmth  = "Warmth"
}

@Observable
@MainActor
final class NetworkViewModel {
    var contacts: [Contact] = [] {
        didSet { invalidateSortCache() }
    }
    var isLoading: Bool = false
    var error: Error? = nil
    var sortOrder: ContactSortOrder = .recency {
        didSet { invalidateSortCache() }
    }
    var searchText: String = "" {
        didSet { invalidateFilterCache() }
    }

    // Cached sorted and filtered arrays — recomputed only when inputs change.
    private(set) var sortedContacts: [Contact] = []
    private(set) var filteredContacts: [Contact] = []

    private func invalidateSortCache() {
        switch sortOrder {
        case .recency:
            sortedContacts = contacts.sorted {
                ($0.lastContactedAt ?? $0.createdAt) > ($1.lastContactedAt ?? $1.createdAt)
            }
        case .warmth:
            sortedContacts = contacts.sorted { $0.warmthScore > $1.warmthScore }
        }
        invalidateFilterCache()
    }

    private func invalidateFilterCache() {
        guard !searchText.isEmpty else {
            filteredContacts = sortedContacts
            return
        }
        let q = searchText.lowercased()
        filteredContacts = sortedContacts
            .compactMap { contact -> (Contact, Int)? in
                let s = [
                    scoreField(contact.name, query: q),
                    scoreField(contact.company, query: q),
                    scoreField(contact.title, query: q),
                    scoreField(contact.howMet, query: q),
                    scoreField(contact.notes, query: q),
                    contact.tags.map { scoreField($0, query: q) }.max() ?? 0
                ].max() ?? 0
                return s > 0 ? (contact, s) : nil
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private func scoreField(_ field: String?, query: String) -> Int {
        guard let f = field?.lowercased() else { return 0 }
        if f == query           { return 4 }
        if f.hasPrefix(query)   { return 3 }
        if f.contains(query)    { return 2 }
        if fuzzyMatch(f, query) { return 1 }
        return 0
    }

    private func fuzzyMatch(_ text: String, _ query: String) -> Bool {
        var idx = text.startIndex
        for ch in query {
            guard let found = text[idx...].firstIndex(of: ch) else { return false }
            idx = text.index(after: found)
        }
        return true
    }

    private let service = SupabaseService.shared

    func loadContacts() async {
        guard let userId = service.currentUserId else {
            self.error = URLError(.userAuthenticationRequired)
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            contacts = try await service.fetchContacts(userId: userId)
        } catch {
            self.error = error
        }
    }

    func createContact(_ draft: ContactDraft) async {
        guard draft.isValid else { return }
        guard let userId = service.currentUserId else { return }
        let payload = ContactInsertPayload(draft: draft, userId: userId)
        error = nil
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
        error = nil
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
        error = nil
        do {
            try await service.deleteContact(id: contact.id)
            contacts.removeAll { $0.id == contact.id }
        } catch {
            self.error = error
        }
    }
}
