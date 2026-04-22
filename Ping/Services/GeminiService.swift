import Foundation

enum EmbeddingTaskType: String {
    case retrievalDocument  = "RETRIEVAL_DOCUMENT"
    case retrievalQuery     = "RETRIEVAL_QUERY"
    case semanticSimilarity = "SEMANTIC_SIMILARITY"
}

struct GeminiService {

    /// Returns a 768-dimensional embedding for the given text via the gemini-embed edge function.
    static func embed(_ text: String, taskType: EmbeddingTaskType = .retrievalDocument) async throws -> [Float] {
        let model = await MainActor.run { RemoteConfigService.shared.config.embeddingModel }
        let body = EmbedRequest(
            text: text,
            taskType: taskType.rawValue,
            model: model
        )
        let response: EmbedResponse = try await APIClient.postEdgeFunction("gemini-embed", body: body)
        return response.values.map { Float($0) }
    }

    // MARK: - Codable Types

    private struct EmbedRequest: Encodable {
        let text: String
        let taskType: String
        let model: String
    }

    private struct EmbedResponse: Decodable {
        let values: [Double]
    }
}
