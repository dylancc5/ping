import Foundation

struct LinkedInImportService {

    // MARK: - Public API

    /// Parses a LinkedIn connections CSV export into ContactDraft values.
    /// LinkedIn CSV column order: First Name, Last Name, URL, Email Address, Company, Position, Connected On
    static func parseCSV(_ url: URL) throws -> [ContactDraft] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        // Normalize line endings, split, drop header row
        let lines = contents
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        return lines
            .dropFirst()                   // skip header
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .compactMap { parseDraft(from: $0) }
    }

    /// Filters out drafts that duplicate an existing contact.
    /// Dedup criteria: same linkedin_url (non-nil) OR same name+company (case-insensitive).
    /// Returns the contacts to import and the count that were skipped.
    static func deduplicateAgainstExisting(
        drafts: [ContactDraft],
        existing: [Contact]
    ) -> (toImport: [ContactDraft], skippedCount: Int) {
        let existingURLs: Set<String> = Set(
            existing.compactMap { $0.linkedinUrl?.lowercased() }
        )
        // name+company key for name-based dedup
        let existingNameCompany: Set<String> = Set(
            existing.compactMap { c -> String? in
                guard let company = c.company else { return nil }
                return "\(c.name.lowercased())|\(company.lowercased())"
            }
        )

        var toImport: [ContactDraft] = []
        var skipped = 0

        for draft in drafts {
            let urlMatch = draft.linkedinUrl.map { existingURLs.contains($0.lowercased()) } ?? false
            let nameMatch: Bool = {
                guard let company = draft.company else { return false }
                let key = "\(draft.name.lowercased())|\(company.lowercased())"
                return existingNameCompany.contains(key)
            }()

            if urlMatch || nameMatch {
                skipped += 1
            } else {
                toImport.append(draft)
            }
        }

        return (toImport, skipped)
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

        let rawURL   = cols.count > 2 ? cols[2].trimmingCharacters(in: .whitespaces) : ""
        let rawEmail = cols.count > 3 ? cols[3].trimmingCharacters(in: .whitespaces) : ""
        let company  = cols.count > 4 ? cols[4].trimmingCharacters(in: .whitespaces) : ""
        let position = cols.count > 5 ? cols[5].trimmingCharacters(in: .whitespaces) : ""
        let connectedOn = cols.count > 6 ? cols[6].trimmingCharacters(in: .whitespaces) : ""

        // Validate LinkedIn URL — must start with https://
        let linkedinUrl: String? = rawURL.lowercased().hasPrefix("https://") ? rawURL : nil

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

    /// Parses LinkedIn's "Connected On" date format: "15 Mar 2026" or "02 Jan 2026"
    private static func parseLinkedInDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.date(from: string)
    }

    /// RFC 4180-compliant CSV row parser.
    /// Handles: quoted fields, escaped quotes (""), embedded commas inside quotes, bare fields.
    private static func parseCSVRow(_ row: String) -> [String] {
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
                        // Escaped quote: "" → append one "
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
