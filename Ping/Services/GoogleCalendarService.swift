import Foundation

struct GoogleCalendarService {

    private static let baseURL = "https://www.googleapis.com/calendar/v3/calendars/primary/events"

    /// Fetches calendar events from the last 30 days and returns attendees as CalendarSuggestion.
    /// Filters out events with fewer than 2 attendees and excludes the current user's own email.
    static func fetchMeetingSuggestions(
        accessToken: String,
        userEmail: String
    ) async throws -> [CalendarSuggestion] {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!

        let iso = ISO8601DateFormatter()
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: iso.string(from: thirtyDaysAgo)),
            URLQueryItem(name: "timeMax", value: iso.string(from: now)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "maxResults", value: "250"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        let response: CalendarEventsResponse = try await googleGet(components.url!, accessToken: accessToken)

        return (response.items ?? [])
            .filter { ($0.attendees?.count ?? 0) >= 2 }
            .flatMap { event -> [CalendarSuggestion] in
                let date = event.start?.dateTime ?? event.start?.date.flatMap { parseDate($0) } ?? now
                return (event.attendees ?? [])
                    .filter { !($0.`self` ?? false) && $0.email != userEmail }
                    .map { attendee in
                        CalendarSuggestion(
                            name: attendee.displayName ?? attendee.email,
                            email: attendee.email,
                            eventTitle: event.summary ?? "Meeting",
                            eventDate: date
                        )
                    }
            }
    }

    // MARK: - Networking

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

    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    // MARK: - Response Types

    private struct CalendarEventsResponse: Decodable {
        let items: [CalendarEvent]?
    }

    private struct CalendarEvent: Decodable {
        let summary: String?
        let start: EventDateTime?
        let attendees: [Attendee]?
    }

    private struct EventDateTime: Decodable {
        let dateTime: Date?
        let date: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decodeIfPresent(String.self, forKey: .date)
            if let raw = try container.decodeIfPresent(String.self, forKey: .dateTime) {
                dateTime = ISO8601DateFormatter().date(from: raw)
            } else {
                dateTime = nil
            }
        }

        enum CodingKeys: String, CodingKey {
            case dateTime, date
        }
    }

    private struct Attendee: Decodable {
        let email: String
        let displayName: String?
        let `self`: Bool?
    }
}
