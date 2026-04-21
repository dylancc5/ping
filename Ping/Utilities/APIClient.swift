import Foundation

enum AIError: Error {
    case httpError(statusCode: Int, body: String)
    case decodingError
    case rateLimitExceeded
}

struct APIClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    /// POST JSON body to a Supabase Edge Function.
    /// Authenticates with the Supabase anon key via Bearer + apikey headers.
    /// Retries once on HTTP 429 after a 2-second delay.
    static func postEdgeFunction<T: Encodable, R: Decodable>(
        _ functionName: String,
        body: T
    ) async throws -> R {
        let urlString = "\(Config.supabaseURL)/functions/v1/\(functionName)"
        guard let url = URL(string: urlString) else {
            throw AIError.httpError(statusCode: 0, body: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(body)

        return try await execute(request: request, isRetry: false)
    }

    private static func execute<R: Decodable>(request: URLRequest, isRetry: Bool) async throws -> R {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.httpError(statusCode: 0, body: "Non-HTTP response")
        }

        switch http.statusCode {
        case 200...299:
            do {
                return try JSONDecoder().decode(R.self, from: data)
            } catch {
                throw AIError.decodingError
            }

        case 429:
            if isRetry { throw AIError.rateLimitExceeded }
            try await Task.sleep(for: .seconds(2))
            return try await execute(request: request, isRetry: true)

        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIError.httpError(statusCode: http.statusCode, body: body)
        }
    }
}
