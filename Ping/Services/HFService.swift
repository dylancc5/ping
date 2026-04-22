import Foundation

enum DraftTone: String, CaseIterable, Identifiable {
    case warmCheckIn    = "Warm check-in"
    case opportunityAsk = "Opportunity ask"
    case casualUpdate   = "Casual update"

    var id: String { rawValue }

    var promptBias: String {
        switch self {
        case .warmCheckIn:
            return "Make it feel like genuine human warmth with no agenda. Just reconnecting."
        case .opportunityAsk:
            return "Naturally weave in a specific opportunity or ask — keep it low-pressure and conversational."
        case .casualUpdate:
            return "Very casual, like catching up with an old friend. Short and breezy."
        }
    }
}

struct HFService {

    // MARK: - Public Methods

    /// Generates a short, tone-calibrated reconnect message draft.
    static func generateDraft(
        contact: Contact,
        nudgeReason: String,
        toneSamples: [String],
        tone: DraftTone? = nil
    ) async throws -> String {
        var toneText = toneSamples.isEmpty
            ? "Conversational, warm, not overly formal. Short sentences. Human."
            : toneSamples.joined(separator: "\n")
        if let tone { toneText += "\n\nTONE DIRECTION: \(tone.promptBias)" }

        let systemPrompt = buildDraftSystemPrompt(contact: contact, nudgeReason: nudgeReason, toneText: toneText)

        let cfg = await MainActor.run { RemoteConfigService.shared.config }
        let body = GenerateRequest(
            prompt: "Draft the message.",
            systemPrompt: systemPrompt,
            temperature: cfg.hfDraftTemperature,
            maxTokens: cfg.hfDraftMaxTokens,
            model: cfg.hfGenerationModel
        )
        let response: GenerateResponse = try await APIClient.postEdgeFunction("hf-generate", body: body)
        return response.text
    }

    /// Extracts structured contact info from a voice transcript.
    static func extractContactFromTranscript(_ transcript: String) async throws -> ContactDraft {
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

        let model = await MainActor.run { RemoteConfigService.shared.config.hfGenerationModel }
        let body = GenerateRequest(
            prompt: prompt,
            systemPrompt: nil,
            temperature: 0.2,
            maxTokens: 256,
            model: model
        )
        let response: GenerateResponse = try await APIClient.postEdgeFunction("hf-generate", body: body)
        return try parseContactDraft(from: response.text)
    }

    /// Extracts a 0.0–1.0 follow-up urgency score from meeting context.
    static func extractMeetingUrgency(howMet: String, notes: String) async throws -> Double {
        let prompt = """
        Rate the follow-up urgency for this contact from 0.0 to 1.0.

        How met: \(howMet)
        Notes: \(notes)

        Consider: Did they mention a specific opportunity, timeline, or ask to stay in touch urgently?

        Respond with only a number between 0.0 and 1.0.
        Examples: casual hallway chat = 0.1, "follow up next week about the role" = 0.9
        """

        let model = await MainActor.run { RemoteConfigService.shared.config.hfGenerationModel }
        let body = GenerateRequest(
            prompt: prompt,
            systemPrompt: nil,
            temperature: 0.1,
            maxTokens: 16,
            model: model
        )
        let response: GenerateResponse = try await APIClient.postEdgeFunction("hf-generate", body: body)
        let value = Double(response.text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.5
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
        guard let data = raw.data(using: .utf8) else { throw AIError.decodingError }
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
            throw AIError.decodingError
        }
    }

    // MARK: - Codable Types

    private struct GenerateRequest: Encodable {
        let prompt: String
        let systemPrompt: String?
        let temperature: Double?
        let maxTokens: Int?
        let model: String?
    }

    private struct GenerateResponse: Decodable {
        let text: String
    }

    private struct ExtractedContact: Decodable {
        let name: String
        let company: String?
        let title: String?
        let howMet: String
        let notes: String?
    }
}
