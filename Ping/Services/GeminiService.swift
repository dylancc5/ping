import Foundation

enum EmbeddingTaskType: String {
    case retrievalDocument  = "RETRIEVAL_DOCUMENT"
    case retrievalQuery     = "RETRIEVAL_QUERY"
    case semanticSimilarity = "SEMANTIC_SIMILARITY"
}

struct GeminiService {

    // MARK: - Endpoints

    private static let embeddingEndpoint =
        "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent"
    private static let generateEndpoint =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    // MARK: - Public Methods

    /// Returns a 768-dimensional embedding for the given text.
    static func embed(_ text: String, taskType: EmbeddingTaskType = .retrievalDocument) async throws -> [Float] {
        let apiKey = Config.geminiAPIKey
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }

        let body = EmbedRequest(
            model: "models/text-embedding-004",
            content: Content(parts: [Part(text: text)]),
            taskType: taskType.rawValue
        )
        let response: EmbedResponse = try await APIClient.post(embeddingEndpoint, body: body, apiKey: apiKey)
        return response.embedding.values
    }

    /// Generates a short, tone-calibrated reconnect message draft.
    static func generateDraft(
        contact: Contact,
        nudgeReason: String,
        toneSamples: [String]
    ) async throws -> String {
        let apiKey = Config.geminiAPIKey
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }

        let toneText = toneSamples.isEmpty
            ? "Conversational, warm, not overly formal. Short sentences. Human."
            : toneSamples.joined(separator: "\n")

        let systemPrompt = buildDraftSystemPrompt(contact: contact, nudgeReason: nudgeReason, toneText: toneText)

        let body = GenerateRequest(
            systemInstruction: Content(parts: [Part(text: systemPrompt)]),
            contents: [Content(parts: [Part(text: "Draft the message.")])],
            generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 200)
        )
        let response: GenerateResponse = try await APIClient.post(generateEndpoint, body: body, apiKey: apiKey)
        return response.candidates.first?.content.parts.first?.text ?? ""
    }

    /// Extracts structured contact info from a voice transcript.
    static func extractContactFromTranscript(_ transcript: String) async throws -> ContactDraft {
        let apiKey = Config.geminiAPIKey
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }

        let prompt = """
        Extract contact information from this voice note about someone the user just met.

        Voice note: "\(transcript)"

        Return JSON with these fields (use null if not mentioned):
        {
          "name": "string",
          "company": "string or null",
          "title": "string or null",
          "how_met": "string",
          "notes": "string or null"
        }

        Be concise. Capture the essence, not a transcript.
        For "how_met": describe the context in 3-6 words ("SCET career fair", "Berkeley CS class")
        """

        let body = GenerateRequest(
            systemInstruction: nil,
            contents: [Content(parts: [Part(text: prompt)])],
            generationConfig: GenerationConfig(temperature: 0.2, maxOutputTokens: 256)
        )
        let response: GenerateResponse = try await APIClient.post(generateEndpoint, body: body, apiKey: apiKey)
        let rawText = response.candidates.first?.content.parts.first?.text ?? ""

        return try parseContactDraft(from: rawText)
    }

    /// Extracts a 0.0–1.0 follow-up urgency score from meeting context.
    static func extractMeetingUrgency(howMet: String, notes: String) async throws -> Double {
        let apiKey = Config.geminiAPIKey
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }

        let prompt = """
        Rate the follow-up urgency for this contact from 0.0 to 1.0.

        How met: \(howMet)
        Notes: \(notes)

        Consider: Did they mention a specific opportunity, timeline, or ask to stay in touch urgently?

        Respond with only a number between 0.0 and 1.0.
        Examples: casual hallway chat = 0.1, "follow up next week about the role" = 0.9
        """

        let body = GenerateRequest(
            systemInstruction: nil,
            contents: [Content(parts: [Part(text: prompt)])],
            generationConfig: GenerationConfig(temperature: 0.1, maxOutputTokens: 16)
        )
        let response: GenerateResponse = try await APIClient.post(generateEndpoint, body: body, apiKey: apiKey)
        let text = response.candidates.first?.content.parts.first?.text ?? ""
        let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.5
        return max(0.0, min(1.0, value))
    }

    // MARK: - Private Helpers

    private static func buildDraftSystemPrompt(contact: Contact, nudgeReason: String, toneText: String) -> String {
        let referenceDate = contact.lastContactedAt ?? contact.createdAt
        let days = Calendar.current.dateComponents([.day], from: referenceDate, to: Date()).day ?? 0

        return """
        You are a personal writing assistant for someone who wants to maintain genuine human relationships.

        Your job is to draft a short, warm, authentic message they can send to reconnect with a contact.

        STRICT RULES:
        - 2-4 sentences maximum. Never more.
        - Sound like the user wrote it, not a robot.
        - No generic openers like "Hope you're doing well!" or "I wanted to reach out"
        - Reference something specific about how they met or what they discussed
        - Make the ask (if any) feel natural and low-pressure
        - Never sound transactional or like you're using someone for something
        - The message should feel like it "just happened to happen"

        USER VOICE (match this style):
        \(toneText)

        CONTACT CONTEXT:
        Name: \(contact.name)
        Company: \(contact.company ?? "unknown")
        Title: \(contact.title ?? "unknown")
        How you met: \(contact.howMet)
        Notes from when you met: \(contact.notes ?? "none")
        Days since you last had contact: \(days)

        REASON FOR REACHING OUT:
        \(nudgeReason)

        Write a message they can send as-is or lightly edit. Don't include a subject line.
        Just the message body. Start directly — no "Here's a draft:" preamble.
        """
    }

    private static func parseContactDraft(from text: String) throws -> ContactDraft {
        var raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("```") {
            let lines = raw.components(separatedBy: "\n")
            raw = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        guard let data = raw.data(using: .utf8) else { throw GeminiError.decodingError }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let extracted = try decoder.decode(ExtractedContact.self, from: data)
            return ContactDraft(
                name: extracted.name,
                company: extracted.company,
                title: extracted.title,
                howMet: extracted.howMet,
                notes: extracted.notes
            )
        } catch {
            throw GeminiError.decodingError
        }
    }

    // MARK: - Codable Types

    private struct Part: Codable {
        let text: String
    }

    private struct Content: Codable {
        let parts: [Part]
    }

    private struct EmbedRequest: Encodable {
        let model: String
        let content: Content
        let taskType: String
    }

    private struct EmbeddingValues: Decodable {
        let values: [Float]
    }

    private struct EmbedResponse: Decodable {
        let embedding: EmbeddingValues
    }

    private struct GenerationConfig: Encodable {
        let temperature: Double?
        let maxOutputTokens: Int?
    }

    private struct GenerateRequest: Encodable {
        let systemInstruction: Content?
        let contents: [Content]
        let generationConfig: GenerationConfig?
    }

    private struct Candidate: Decodable {
        let content: Content
    }

    private struct GenerateResponse: Decodable {
        let candidates: [Candidate]
    }

    private struct ExtractedContact: Decodable {
        let name: String
        let company: String?
        let title: String?
        let howMet: String
        let notes: String?
    }
}
