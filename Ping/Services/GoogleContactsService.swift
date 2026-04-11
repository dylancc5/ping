import Foundation

struct GoogleContactsService {

    private static let baseURL = "https://people.googleapis.com/v1/people/me/connections"
    private static let fields  = "names,emailAddresses,organizations,phoneNumbers"

    /// Fetches all Google Contacts via the People API and maps them to ContactDraft.
    static func fetchContacts(accessToken: String) async throws -> [ContactDraft] {
        var all: [GooglePerson] = []
        var pageToken: String? = nil

        repeat {
            var components = URLComponents(string: baseURL)!
            var items: [URLQueryItem] = [
                URLQueryItem(name: "personFields", value: fields),
                URLQueryItem(name: "pageSize", value: "1000")
            ]
            if let token = pageToken {
                items.append(URLQueryItem(name: "pageToken", value: token))
            }
            components.queryItems = items

            let response: ConnectionsResponse = try await googleGet(components.url!, accessToken: accessToken)
            all.append(contentsOf: response.connections ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil

        return all.compactMap { person -> ContactDraft? in
            guard let name = person.names?.first?.displayName, !name.isEmpty else { return nil }
            return ContactDraft(
                name: name,
                company: person.organizations?.first?.name,
                title: person.organizations?.first?.title,
                howMet: "Google Contact",
                email: person.emailAddresses?.first?.value,
                phone: person.phoneNumbers?.first?.value
            )
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

    // MARK: - Response Types

    private struct ConnectionsResponse: Decodable {
        let connections: [GooglePerson]?
        let nextPageToken: String?
    }

    private struct GooglePerson: Decodable {
        let names: [PersonName]?
        let emailAddresses: [PersonEmail]?
        let organizations: [PersonOrg]?
        let phoneNumbers: [PersonPhone]?
    }

    private struct PersonName: Decodable {
        let displayName: String?
    }

    private struct PersonEmail: Decodable {
        let value: String?
    }

    private struct PersonOrg: Decodable {
        let name: String?
        let title: String?
    }

    private struct PersonPhone: Decodable {
        let value: String?
    }
}
