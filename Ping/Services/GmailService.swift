import Foundation

/// Shared error type for Google REST API calls.
enum GoogleAPIError: Error {
    case httpError(statusCode: Int, body: String)
}

struct GmailService {

    // PRIVACY: This service only ever requests message metadata (format=METADATA with
    // metadataHeaders=To). It never requests format=FULL or format=RAW. Email body
    // content is never fetched, stored, or processed by Ping under any circumstances.

    private static let messagesURL = "https://gmail.googleapis.com/gmail/v1/users/me/messages"

    /// Fetches the top-25 recipients emailed at least once in the last 25 days of sent mail.
    /// Only reads To: headers — never email body content.
    static func fetchContactSuggestions(accessToken: String) async throws -> [ContactSuggestion] {
        let messageList = try await fetchSentMessageList(accessToken: accessToken)

        var recipientCounts: [String: (name: String, count: Int)] = [:]

        for message in messageList {
            guard let toHeader = try await fetchToHeader(accessToken: accessToken, messageId: message.id) else {
                continue
            }
            for (name, email) in parseToHeader(toHeader) {
                let existing = recipientCounts[email]
                recipientCounts[email] = (name: name, count: (existing?.count ?? 0) + 1)
            }
        }

        return recipientCounts
            .filter { $0.value.count >= 1 }
            .map { (email, data) in
                ContactSuggestion(name: data.name, email: email, frequency: data.count)
            }
            .sorted { $0.frequency > $1.frequency }
            .prefix(25)
            .map { $0 }
    }

    // MARK: - Private Helpers

    private static func fetchSentMessageList(accessToken: String) async throws -> [MessageStub] {
        var components = URLComponents(string: messagesURL)!
        components.queryItems = [
            URLQueryItem(name: "labelIds", value: "SENT"),
            URLQueryItem(name: "q", value: "newer_than:25d"),
            URLQueryItem(name: "maxResults", value: "200")
        ]
        let response: MessageListResponse = try await googleGet(components.url!, accessToken: accessToken)
        return response.messages ?? []
    }

    /// Fetches only the To: header for a single message.
    /// Uses format=METADATA to ensure the body is never transmitted or stored.
    private static func fetchToHeader(accessToken: String, messageId: String) async throws -> String? {
        var components = URLComponents(string: "\(messagesURL)/\(messageId)")!
        components.queryItems = [
            URLQueryItem(name: "format", value: "METADATA"),
            URLQueryItem(name: "metadataHeaders", value: "To")
        ]
        let response: MessageMetadata = try await googleGet(components.url!, accessToken: accessToken)
        return response.payload?.headers?.first(where: { $0.name == "To" })?.value
    }

    /// Parses a To: header value into (name, email) pairs.
    /// Handles both `"Name" <email@example.com>` and bare `email@example.com` formats.
    private static func parseToHeader(_ header: String) -> [(name: String, email: String)] {
        return header
            .components(separatedBy: ",")
            .compactMap { part -> (String, String)? in
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                // "Display Name" <email@example.com>
                if let langle = trimmed.lastIndex(of: "<"),
                   let rangle = trimmed.lastIndex(of: ">"),
                   langle < rangle {
                    let email = String(trimmed[trimmed.index(after: langle)..<rangle])
                        .trimmingCharacters(in: .whitespaces)
                    let name = trimmed[..<langle]
                        .trimmingCharacters(in: .init(charactersIn: " \""))
                    guard !email.isEmpty else { return nil }
                    return (name.isEmpty ? email : name, email)
                }
                // bare email
                let email = trimmed
                guard email.contains("@") else { return nil }
                return (email, email)
            }
    }

    private static func googleGet<R: Decodable>(_ url: URL, accessToken: String) async throws -> R {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GoogleAPIError.httpError(statusCode: code, body: body)
        }
        return try JSONDecoder().decode(R.self, from: data)
    }

    // MARK: - Response Types

    private struct MessageListResponse: Decodable {
        let messages: [MessageStub]?
    }

    private struct MessageStub: Decodable {
        let id: String
    }

    private struct MessageMetadata: Decodable {
        let payload: MessagePayload?
    }

    private struct MessagePayload: Decodable {
        let headers: [MessageHeader]?
    }

    private struct MessageHeader: Decodable {
        let name: String
        let value: String
    }
}
