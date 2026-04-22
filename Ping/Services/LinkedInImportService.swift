import Foundation

// MARK: - Dedup Result

enum DedupeResult {
    case insert(ContactDraft)
    case update(existing: Contact, draft: ContactDraft)
}

// MARK: - LinkedInImportService

struct LinkedInImportService {

    // MARK: - Public API

    /// Parses a LinkedIn connections CSV export into ContactDraft values.
    /// Handles the LinkedIn export format which includes a multi-line Notes
    /// preamble before the actual header row:
    ///   Notes:
    ///   "When exporting your connection data..."
    ///   (blank)
    ///   First Name,Last Name,URL,Email Address,Company,Position,Connected On
    ///   Melody,Law,...
    static func parseCSV(_ url: URL) throws -> [ContactDraft] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        // Find the real header row by looking for a line whose first field is "First Name".
        // Falls back to index 0 so plain CSVs without a preamble still work.
        let headerIndex = lines.firstIndex(where: { line in
            let cols = parseCSVRow(line)
            return cols.first?.trimmingCharacters(in: .whitespaces) == "First Name"
        }) ?? 0

        return lines
            .dropFirst(headerIndex + 1)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .compactMap { parseDraft(from: $0) }
    }

    /// Classifies each draft as a new insert or an update to an existing contact.
    ///
    /// Identity hierarchy (first match wins):
    ///   1. Normalized LinkedIn URL
    ///   2. Lowercased email
    ///   3. Lowercased name + company (only when both sides have a company)
    static func classify(
        drafts: [ContactDraft],
        existing: [Contact]
    ) -> [DedupeResult] {
        // Build lookup maps for O(1) matching
        var byURL:         [String: Contact] = [:]
        var byEmail:       [String: Contact] = [:]
        var byNameCompany: [String: Contact] = [:]

        for c in existing {
            if let url = normalizeLinkedInURL(c.linkedinUrl) {
                byURL[url] = c
            }
            if let email = c.email?.lowercased().trimmingCharacters(in: .whitespaces), !email.isEmpty {
                byEmail[email] = c
            }
            if let company = c.company {
                let key = "\(c.name.lowercased())|\(company.lowercased())"
                byNameCompany[key] = c
            }
        }

        return drafts.map { draft in
            // 1. LinkedIn URL
            if let url = normalizeLinkedInURL(draft.linkedinUrl), let match = byURL[url] {
                return .update(existing: match, draft: draft)
            }
            // 2. Email
            if let email = draft.email?.lowercased().trimmingCharacters(in: .whitespaces),
               !email.isEmpty, let match = byEmail[email] {
                return .update(existing: match, draft: draft)
            }
            // 3. Name + Company (both sides must have company)
            if let company = draft.company {
                let key = "\(draft.name.lowercased())|\(company.lowercased())"
                if let match = byNameCompany[key] {
                    return .update(existing: match, draft: draft)
                }
            }
            return .insert(draft)
        }
    }

    // MARK: - URL Normalization

    static func normalizeLinkedInURL(_ url: String?) -> String? {
        guard var s = url?.lowercased().trimmingCharacters(in: .whitespaces),
              !s.isEmpty else { return nil }
        if s.hasSuffix("/") { s = String(s.dropLast()) }
        if let q = s.firstIndex(of: "?") { s = String(s[s.startIndex..<q]) }
        return s
    }

    // MARK: - Private

    private static func parseDraft(from row: String) -> ContactDraft? {
        let cols = parseCSVRow(row)
        guard cols.count >= 2 else { return nil }

        let firstName = cols[0].trimmingCharacters(in: .whitespaces)
        let lastName  = cols.count > 1 ? cols[1].trimmingCharacters(in: .whitespaces) : ""
        let fullName  = [firstName, lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !fullName.isEmpty else { return nil }

        let rawURL      = cols.count > 2 ? cols[2].trimmingCharacters(in: .whitespaces) : ""
        let rawEmail    = cols.count > 3 ? cols[3].trimmingCharacters(in: .whitespaces) : ""
        let company     = cols.count > 4 ? cols[4].trimmingCharacters(in: .whitespaces) : ""
        let position    = cols.count > 5 ? cols[5].trimmingCharacters(in: .whitespaces) : ""
        let connectedOn = cols.count > 6 ? cols[6].trimmingCharacters(in: .whitespaces) : ""

        // Validate and normalize LinkedIn URL
        let linkedinUrl: String? = rawURL.lowercased().hasPrefix("https://")
            ? normalizeLinkedInURL(rawURL)
            : nil

        var draft = ContactDraft()
        draft.name        = fullName
        draft.company     = company.isEmpty ? nil : company
        draft.title       = position.isEmpty ? nil : position
        draft.howMet      = "LinkedIn connection"
        draft.linkedinUrl = linkedinUrl
        draft.email       = rawEmail.isEmpty ? nil : rawEmail
        draft.metAt       = parseLinkedInDate(connectedOn)
        return draft
    }

    private static func parseLinkedInDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.date(from: string)
    }

    /// RFC 4180-compliant CSV row parser.
    /// Handles: quoted fields, escaped quotes (""), embedded commas inside quotes, bare fields.
    static func parseCSVRow(_ row: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var idx = row.startIndex

        while idx < row.endIndex {
            let ch = row[idx]

            if inQuotes {
                if ch == "\"" {
                    let next = row.index(after: idx)
                    if next < row.endIndex && row[next] == "\"" {
                        current.append("\"")
                        idx = row.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            }

            idx = row.index(after: idx)
        }

        fields.append(current)
        return fields
    }
}
