# Ping — Integrations

## Overview

Ping integrates with three external systems in v1:
1. **LinkedIn** — CSV bulk import + iOS Share Sheet extension
2. **Google** — Contacts import, Calendar scan, Gmail contact suggestions
3. **iOS Share Sheet** — Generic contact capture from any profile URL

The integration philosophy: **meet users where they already are**. Don't make them build a new habit from scratch — layer Ping onto the tools they're using every day.

---

## 1. LinkedIn Integration

### 1a. LinkedIn CSV Import

LinkedIn allows any user to export their connections as a CSV from Settings. This is Ping's bulk onboarding mechanism — get your entire network into Ping in one step.

**LinkedIn CSV format:**

```csv
First Name,Last Name,URL,Email Address,Company,Position,Connected On
Marcus,Chen,https://www.linkedin.com/in/marcuschen/,marcus@google.com,Google,Product Manager,15 Mar 2026
Sarah,Kim,,sarahkim,Stripe,PM,02 Jan 2026
```

Fields available:
- `First Name`, `Last Name` → `contacts.name`
- `URL` → `contacts.linkedin_url`
- `Email Address` → `contacts.email`
- `Company` → `contacts.company`
- `Position` → `contacts.title`
- `Connected On` → `contacts.met_at` (parsed as "Connected on LinkedIn")
- `how_met` → auto-set to "LinkedIn connection" for all CSV imports

**iOS implementation:**

```swift
// LinkedInImportService.swift

struct LinkedInImportService {

    static func parseCSV(_ url: URL) throws -> [ContactDraft] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let rows = contents.components(separatedBy: "\n").dropFirst() // skip header

        return rows.compactMap { row -> ContactDraft? in
            let cols = parseCSVRow(row)
            guard cols.count >= 6,
                  !cols[0].isEmpty || !cols[1].isEmpty else { return nil }

            return ContactDraft(
                name: "\(cols[0]) \(cols[1])".trimmingCharacters(in: .whitespaces),
                company: cols.count > 4 ? cols[4] : nil,
                title: cols.count > 5 ? cols[5] : nil,
                howMet: "LinkedIn connection",
                notes: nil,
                linkedinUrl: cols.count > 2 ? cols[2] : nil,
                email: cols.count > 3 ? cols[3] : nil
            )
        }
    }

    // RFC 4180-compliant CSV parser (handles quoted fields with commas)
    private static func parseCSVRow(_ row: String) -> [String] { ... }
}
```

**Import flow:**

1. User goes to Profile tab → LinkedIn → Import CSV
2. App shows instructions: "Go to LinkedIn → Me → Settings → Data Privacy → Get a copy of your data → Connections"
3. File picker opens (`.csv` file type)
4. App parses CSV, shows preview: "Found 156 connections — import all or review first?"
5. On confirm: batch insert into Supabase, generate embeddings in background (throttled to stay in free tier)
6. Progress indicator: "Importing 45/156..."

**Deduplication:**
- Before inserting, check for existing contact with same `linkedin_url` or same name + company
- If duplicate found: skip and surface a "X duplicates skipped" count at end

### 1b. Share Sheet Extension

An iOS Share Extension that appears when the user taps "Share" on a LinkedIn profile page (in Safari or LinkedIn app), any URL, or a business card photo.

**Extension target:** `PingShareExtension` — a separate app extension target in the Xcode project.

**Activation contexts:**
- LinkedIn profile URL: `https://www.linkedin.com/in/handle/`
- Any web page URL (generic fallback)

**Implementation:**

```swift
// ShareViewController.swift (in PingShareExtension target)

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first else {
            cancel()
            return
        }

        if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, error in
                if let url = item as? URL {
                    self?.handleURL(url)
                }
            }
        }
    }

    func handleURL(_ url: URL) {
        if url.host?.contains("linkedin.com") == true {
            // Parse LinkedIn profile slug from URL
            // Call Gemini to extract available info from URL structure
            // Pre-fill Quick Capture fields
        } else {
            // Generic: just pre-fill the notes with the URL for context
        }

        // Present embedded QuickCaptureView
        presentCaptureInterface()
    }
}
```

**What gets pre-filled from a LinkedIn URL:**
- `linkedin_url` → the URL itself
- Name, company, title → parsed from page title / OG meta tags if available (requires a lightweight web fetch in the extension context)
- `how_met` → left empty for user to fill in (this is the important context Ping needs)

---

## 2. Google Integration

Requires Google Sign-In with the following OAuth scopes:

| Scope | Why |
|-------|-----|
| `profile` | Basic profile info |
| `email` | Account email |
| `https://www.googleapis.com/auth/contacts.readonly` | Read Google Contacts |
| `https://www.googleapis.com/auth/calendar.readonly` | Read calendar events |
| `https://www.googleapis.com/auth/gmail.readonly` | Read Gmail for contact extraction |

**Consent screen copy:**
> "Ping will read your Google Contacts, Calendar, and Gmail to help you find people to add to your network. Ping never reads the content of your emails — only sender names and email addresses."

### 2a. Google Contacts Import

Use the Google People API to fetch the user's contacts.

**Endpoint:** `GET https://people.googleapis.com/v1/people/me/connections`

**Fields to request:** `names,emailAddresses,organizations,phoneNumbers,urls`

```swift
// GoogleContactsService.swift

struct GoogleContactsService {

    static func fetchContacts(accessToken: String) async throws -> [ContactDraft] {
        var allConnections: [GooglePerson] = []
        var pageToken: String? = nil

        repeat {
            let response = try await fetchPage(accessToken: accessToken, pageToken: pageToken)
            allConnections.append(contentsOf: response.connections ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil

        return allConnections.compactMap { person -> ContactDraft? in
            guard let name = person.names?.first?.displayName,
                  !name.isEmpty else { return nil }

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
}
```

### 2b. Calendar Scan

Scan the user's Google Calendar for past meetings with people who aren't in Ping yet. Surface suggestions: "You met with 3 new people this week — want to add them?"

**Logic:**

1. Fetch events from the past 30 days: `GET /calendar/v3/calendars/primary/events`
2. For each event with ≥ 2 attendees: extract attendee names + emails
3. Cross-reference against existing Ping contacts (by email)
4. Surface unrecognized attendees as suggestions with event context as `how_met`

```swift
// GoogleCalendarService.swift

struct CalendarSuggestion {
    let name: String
    let email: String
    let eventTitle: String     // "Ping 1:1" → used as how_met context
    let eventDate: Date
}

static func fetchMeetingsSuggestions(accessToken: String) async throws -> [CalendarSuggestion] {
    let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    let events = try await fetchEvents(
        accessToken: accessToken,
        timeMin: thirtyDaysAgo,
        timeMax: Date()
    )

    let myEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""

    return events
        .filter { $0.attendees?.count ?? 0 >= 2 }
        .flatMap { event in
            (event.attendees ?? [])
                .filter { $0.email != myEmail && !$0.self }
                .map { attendee in
                    CalendarSuggestion(
                        name: attendee.displayName ?? attendee.email,
                        email: attendee.email,
                        eventTitle: event.summary ?? "Meeting",
                        eventDate: event.start.dateTime ?? Date()
                    )
                }
        }
}
```

**UI:** Shown in Profile tab or as an inline banner in Network tab: "You met 3 people recently — add them to Ping?"

### 2c. Gmail Contact Suggestions

Scan Gmail for people the user emails frequently who aren't in Ping.

**Logic:**
1. Fetch recent sent emails (last 90 days): `GET /gmail/v1/users/me/messages?labelIds=SENT`
2. Extract `To:` headers — get name + email for each recipient
3. Count frequency — anyone emailed 3+ times is a suggestion candidate
4. Cross-reference against existing Ping contacts by email
5. Surface top-10 suggestions

**Important privacy note:** Ping only reads email headers (To, From, Subject) — never email body content. This must be clearly communicated in the consent screen and privacy policy.

```swift
// GmailService.swift

static func fetchContactSuggestions(accessToken: String) async throws -> [ContactSuggestion] {
    // Fetch sent message IDs (metadata only)
    let messages = try await fetchMessageList(
        accessToken: accessToken,
        query: "in:sent newer_than:90d",
        maxResults: 200
    )

    // Fetch headers only for each message (not body — never body)
    var recipientCounts: [String: (name: String, count: Int)] = [:]

    for message in messages {
        let headers = try await fetchMessageHeaders(accessToken: accessToken, messageId: message.id)
        if let to = headers["To"] {
            let parsed = parseEmailHeader(to) // returns [(name, email)]
            for (name, email) in parsed {
                recipientCounts[email] = (name: name, count: (recipientCounts[email]?.count ?? 0) + 1)
            }
        }
    }

    return recipientCounts
        .filter { $0.value.count >= 3 }
        .map { (email, data) in ContactSuggestion(name: data.name, email: email, frequency: data.count) }
        .sorted { $0.frequency > $1.frequency }
        .prefix(10)
        .map { $0 }
}
```

---

## 3. iOS OAuth Flow

Google OAuth is handled via the Google Sign-In SDK for iOS.

```swift
// GoogleAuthService.swift

import GoogleSignIn

struct GoogleAuthService {

    static func signIn(presenting viewController: UIViewController) async throws -> GIDGoogleUser {
        let config = GIDConfiguration(clientID: Config.googleClientID)
        GIDSignIn.sharedInstance.configuration = config

        let scopes = [
            "https://www.googleapis.com/auth/contacts.readonly",
            "https://www.googleapis.com/auth/calendar.readonly",
            "https://www.googleapis.com/auth/gmail.readonly"
        ]

        return try await GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            hint: nil,
            additionalScopes: scopes
        ).user
    }

    static func getAccessToken(user: GIDGoogleUser) async throws -> String {
        try await user.refreshTokensIfNeeded()
        return user.accessToken.tokenString
    }
}
```

Google OAuth tokens are stored in the iOS Keychain by the Google Sign-In SDK automatically.

---

## 4. Integration Status in Profile Tab

```
INTEGRATIONS
────────────────────────────────────
[in] LinkedIn
     ✓ 156 contacts imported          →
     Share Sheet: enabled

[G]  Google
     ✓ Connected as dylancc5@         →
       Contacts: 89 imported
       Calendar: scanning...
       Gmail: 12 suggestions pending
```

Each integration row is tappable → shows detail view with re-sync, disconnect options.

---

## 5. V2 Integrations (Not in Scope Now)

- **Twitter/X** — follow graph + profile share sheet
- **Luma/Partiful** — event attendee lists
- **Cal.com / Calendly** — meeting participants
- **LinkedIn API** (if access ever granted) — real-time connection sync
- **iCloud Contacts** — native iOS contacts sync (low priority, most contacts already in Google)
