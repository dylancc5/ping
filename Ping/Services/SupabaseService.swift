import Foundation
import Supabase

// MARK: - RPC result types

struct ContactSearchResult: Identifiable, Decodable, Sendable {
    let id: UUID
    let name: String
    let company: String?
    let title: String?
    let howMet: String
    let warmthScore: Double
    let lastContactedAt: Date?
    let similarity: Double

    enum CodingKeys: String, CodingKey {
        case id, name, company, title, similarity
        case howMet          = "how_met"
        case warmthScore     = "warmth_score"
        case lastContactedAt = "last_contacted_at"
    }
}

struct GoalContactMatch: Identifiable, Decodable, Sendable {
    let id: UUID
    let name: String
    let company: String?
    let title: String?
    let similarity: Double
}

// MARK: - RPC parameter types

private struct MatchContactsParams: Encodable {
    let queryEmbedding: [Float]
    let userIdFilter: UUID
    let matchThreshold: Double
    let matchCount: Int

    enum CodingKeys: String, CodingKey {
        case queryEmbedding  = "query_embedding"
        case userIdFilter    = "user_id_filter"
        case matchThreshold  = "match_threshold"
        case matchCount      = "match_count"
    }
}

private struct MatchContactsForGoalParams: Encodable {
    let goalIdParam: UUID
    let userIdFilter: UUID
    let matchThreshold: Double
    let matchCount: Int

    enum CodingKeys: String, CodingKey {
        case goalIdParam    = "goal_id_param"
        case userIdFilter   = "user_id_filter"
        case matchThreshold = "match_threshold"
        case matchCount     = "match_count"
    }
}

// MARK: - SupabaseService

actor SupabaseService {
    static let shared = SupabaseService()

    private let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    // MARK: - Auth

    var currentUserId: UUID? {
        client.auth.currentUser?.id
    }

    func signOut() async throws {
        try await client.auth.signOut()
        clearSharedSession()
    }

    func signInWithApple(idToken: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )
        persistSessionForExtension()
    }

    func signInWithGoogle(idToken: String, accessToken: String, nonce: String?) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken, nonce: nonce)
        )
        persistSessionForExtension()
    }

    var authStateChanges: AsyncStream<(AuthChangeEvent, Session?)> {
        AsyncStream { continuation in
            Task {
                for await (event, session) in client.auth.authStateChanges {
                    continuation.yield((event, session))
                }
                continuation.finish()
            }
        }
    }

    /// Call this after a successful sign-in to share auth tokens with the Share Extension
    /// via the App Group UserDefaults container. The extension reads these to restore its session.
    /// TODO: Migrate to a shared Keychain Access Group in v2 so the Supabase SDK handles
    /// this automatically without manual token passing.
    func persistSessionForExtension() {
        guard let session = client.auth.currentSession else { return }
        let defaults = UserDefaults(suiteName: "group.com.v1.ping")
        defaults?.set(session.accessToken, forKey: "supabase_access_token")
        defaults?.set(session.refreshToken, forKey: "supabase_refresh_token")
    }

    private func clearSharedSession() {
        let defaults = UserDefaults(suiteName: "group.com.v1.ping")
        defaults?.removeObject(forKey: "supabase_access_token")
        defaults?.removeObject(forKey: "supabase_refresh_token")
    }

    // MARK: - Contacts

    func fetchContacts(userId: UUID) async throws -> [Contact] {
        try await client
            .from("contacts")
            .select()
            .eq("user_id", value: userId)
            .order("warmth_score", ascending: false)
            .execute()
            .value
    }

    func fetchContact(id: UUID) async throws -> Contact {
        try await client
            .from("contacts")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createContact(payload: ContactInsertPayload) async throws -> Contact {
        try await client
            .from("contacts")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func updateContact(id: UUID, fields: [String: AnyJSON]) async throws {
        try await client
            .from("contacts")
            .update(fields)
            .eq("id", value: id)
            .execute()
    }

    /// Writes a Gemini embedding to the contacts table.
    /// `embeddingString` must be a PostgreSQL array literal, e.g. "[0.1,0.2,...]".
    func updateContactEmbedding(id: UUID, embeddingString: String) async throws {
        try await client
            .from("contacts")
            .update(["embedding": AnyJSON.string(embeddingString)])
            .eq("id", value: id)
            .execute()
    }

    func deleteContact(id: UUID) async throws {
        try await client
            .from("contacts")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Interactions

    func fetchInteractions(contactId: UUID) async throws -> [Interaction] {
        try await client
            .from("interactions")
            .select()
            .eq("contact_id", value: contactId)
            .order("occurred_at", ascending: false)
            .execute()
            .value
    }

    func createInteraction(_ interaction: Interaction) async throws -> Interaction {
        try await client
            .from("interactions")
            .insert(interaction)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Nudges

    func fetchPendingNudges(userId: UUID) async throws -> [Nudge] {
        try await client
            .from("nudges")
            .select()
            .eq("user_id", value: userId)
            .eq("status", value: NudgeStatus.pending.rawValue)
            .order("scheduled_at", ascending: true)
            .execute()
            .value
    }

    func fetchNudges(contactId: UUID) async throws -> [Nudge] {
        try await client
            .from("nudges")
            .select()
            .eq("contact_id", value: contactId)
            .order("scheduled_at", ascending: false)
            .execute()
            .value
    }

    func updateNudgeStatus(id: UUID, status: NudgeStatus, snoozedUntil: Date? = nil) async throws {
        var fields: [String: AnyJSON] = ["status": .string(status.rawValue)]
        if let snoozeDate = snoozedUntil {
            fields["snoozed_until"] = .string(iso8601String(from: snoozeDate))
        }
        if status == .acted {
            fields["acted_at"] = .string(iso8601String(from: Date()))
        }
        try await client
            .from("nudges")
            .update(fields)
            .eq("id", value: id)
            .execute()
    }

    func updateNudgeDraft(id: UUID, draftMessage: String) async throws {
        try await client
            .from("nudges")
            .update(["draft_message": AnyJSON.string(draftMessage)])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Goals

    func fetchGoals(userId: UUID) async throws -> [Goal] {
        try await client
            .from("goals")
            .select()
            .eq("user_id", value: userId)
            .eq("active", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createGoal(userId: UUID, text: String) async throws -> Goal {
        struct GoalInsertPayload: Encodable {
            let userId: UUID
            let text: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case text
            }
        }
        return try await client
            .from("goals")
            .insert(GoalInsertPayload(userId: userId, text: text))
            .select()
            .single()
            .execute()
            .value
    }

    /// Writes a Gemini embedding to the goals table.
    /// `embeddingString` must be a PostgreSQL array literal, e.g. "[0.1,0.2,...]".
    func updateGoalEmbedding(id: UUID, embeddingString: String) async throws {
        try await client
            .from("goals")
            .update(["embedding": AnyJSON.string(embeddingString)])
            .eq("id", value: id)
            .execute()
    }

    func deactivateGoal(id: UUID) async throws {
        try await client
            .from("goals")
            .update(["active": AnyJSON.bool(false)])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Semantic Search RPCs

    func matchContacts(
        queryEmbedding: [Float],
        userId: UUID,
        threshold: Double = 0.5,
        count: Int = 10
    ) async throws -> [ContactSearchResult] {
        let params = MatchContactsParams(
            queryEmbedding: queryEmbedding,
            userIdFilter: userId,
            matchThreshold: threshold,
            matchCount: count
        )
        return try await client
            .rpc("match_contacts", params: params)
            .execute()
            .value
    }

    func matchContactsForGoal(
        goalId: UUID,
        userId: UUID,
        threshold: Double = 0.45,
        count: Int = 5
    ) async throws -> [GoalContactMatch] {
        let params = MatchContactsForGoalParams(
            goalIdParam: goalId,
            userIdFilter: userId,
            matchThreshold: threshold,
            matchCount: count
        )
        return try await client
            .rpc("match_contacts_for_goal", params: params)
            .execute()
            .value
    }

    // MARK: - Push Notifications

    /// Persist the APNs device token for the current user.
    /// Called from AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:).
    func saveDeviceToken(_ token: String) async throws {
        guard let userId = currentUserId else { return }
        try await client
            .from("profiles")
            .update(["device_token": AnyJSON.string(token)])
            .eq("id", value: userId)
            .execute()
    }

    // MARK: - Profiles

    private struct ProfileRow: Decodable {
        let toneSamples: [String]?
        enum CodingKeys: String, CodingKey { case toneSamples = "tone_samples" }
    }

    private struct ToneSampleUpsert: Encodable {
        let id: UUID
        let toneSamples: [String]
        enum CodingKeys: String, CodingKey {
            case id
            case toneSamples = "tone_samples"
        }
    }

    func hasToneSamples(userId: UUID) async throws -> Bool {
        let row: ProfileRow = try await client
            .from("profiles")
            .select("tone_samples")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return !(row.toneSamples ?? []).isEmpty
    }

    func fetchToneSamples(userId: UUID) async throws -> [String] {
        let row: ProfileRow = try await client
            .from("profiles")
            .select("tone_samples")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return row.toneSamples ?? []
    }

    func saveToneSample(_ text: String, userId: UUID) async throws {
        let payload = ToneSampleUpsert(id: userId, toneSamples: [text])
        try await client
            .from("profiles")
            .upsert(payload, onConflict: "id")
            .execute()
    }

    // MARK: - Helpers

    private func iso8601String(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

// MARK: - Embedding helper

extension [Float] {
    /// Serializes a float array to a PostgreSQL vector literal accepted by pgvector.
    /// Example output: "[0.12345,-0.67890,...]"
    var pgVectorLiteral: String {
        "[\(map { String($0) }.joined(separator: ","))]"
    }
}
