import Foundation

enum GeminiError: Error {
    case missingAPIKey
    case httpError(statusCode: Int, body: String)
    case decodingError
    case rateLimitExceeded
}

struct APIClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    /// POST JSON body to a URL with an API key query parameter.
    /// Retries once on HTTP 429 after a 2-second delay.
    static func post<T: Encodable, R: Decodable>(
        _ urlString: String,
        body: T,
        apiKey: String
    ) async throws -> R {
        guard var components = URLComponents(string: urlString) else {
            throw GeminiError.httpError(statusCode: 0, body: "Invalid URL")
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            throw GeminiError.httpError(statusCode: 0, body: "Invalid URL after adding key")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        return try await execute(request: request, isRetry: false)
    }

    private static func execute<R: Decodable>(request: URLRequest, isRetry: Bool) async throws -> R {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.httpError(statusCode: 0, body: "Non-HTTP response")
        }

        switch http.statusCode {
        case 200...299:
            do {
                return try JSONDecoder().decode(R.self, from: data)
            } catch {
                throw GeminiError.decodingError
            }

        case 429:
            if isRetry { throw GeminiError.rateLimitExceeded }
            try await Task.sleep(for: .seconds(2))
            return try await execute(request: request, isRetry: true)

        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GeminiError.httpError(statusCode: http.statusCode, body: body)
        }
    }
}
