# Ping — Engineering Setup

## Prerequisites

Before writing a line of code, you'll need these accounts and keys:

| Service | What to do | Where |
|---------|-----------|-------|
| Supabase | Create a new project named "ping" | supabase.com |
| Google AI Studio | Get a free Gemini API key | aistudio.google.com |
| Apple Developer | Enroll (required for Sign in with Apple, push, TestFlight) | developer.apple.com |
| Google Cloud | Create project, enable APIs (see below) | console.cloud.google.com |

---

## Xcode Project Setup

### Project Structure

```
Ping/
├── Ping.xcodeproj
├── Ping/                          # Main app target
│   ├── PingApp.swift
│   ├── Info.plist
│   ├── Assets.xcassets
│   ├── Models/
│   │   ├── Contact.swift
│   │   ├── Interaction.swift
│   │   ├── Nudge.swift
│   │   └── Goal.swift
│   ├── Services/
│   │   ├── SupabaseService.swift
│   │   ├── GeminiService.swift
│   │   ├── NudgeService.swift
│   │   ├── SpeechService.swift
│   │   ├── LinkedInImportService.swift
│   │   ├── GoogleAuthService.swift
│   │   ├── GoogleContactsService.swift
│   │   ├── GoogleCalendarService.swift
│   │   └── GmailService.swift
│   ├── ViewModels/
│   │   ├── PingViewModel.swift
│   │   ├── NetworkViewModel.swift
│   │   ├── SearchViewModel.swift
│   │   └── ContactViewModel.swift
│   ├── Views/
│   │   ├── Auth/
│   │   │   ├── WelcomeView.swift
│   │   │   └── ToneSetupView.swift
│   │   ├── Tabs/
│   │   │   ├── PingTabView.swift
│   │   │   ├── NetworkTabView.swift
│   │   │   ├── SearchTabView.swift
│   │   │   └── ProfileTabView.swift
│   │   ├── Contacts/
│   │   │   ├── ContactListView.swift
│   │   │   ├── ContactCardGridView.swift
│   │   │   ├── ContactDetailView.swift
│   │   │   └── QuickCaptureView.swift
│   │   ├── Nudges/
│   │   │   ├── NudgeCardView.swift
│   │   │   └── MessageDraftView.swift
│   │   ├── Search/
│   │   │   ├── SemanticSearchView.swift
│   │   │   └── GoalsPanelView.swift
│   │   └── Components/
│   │       ├── WarmthDot.swift
│   │       ├── ContactRowView.swift
│   │       ├── ContactAvatarView.swift
│   │       ├── PingButton.swift
│   │       └── LoadingShimmer.swift
│   ├── Extensions/
│   │   ├── Color+Ping.swift
│   │   ├── Date+Ping.swift
│   │   └── View+Ping.swift
│   └── Utilities/
│       ├── KeychainHelper.swift
│       ├── Config.swift
│       └── APIClient.swift
├── PingShareExtension/            # iOS Share Extension target
│   ├── ShareViewController.swift
│   └── Info.plist
└── supabase/                      # Supabase config (in repo)
    ├── migrations/
    │   ├── 001_initial_schema.sql
    │   ├── 002_enable_pgvector.sql
    │   └── 003_rls_policies.sql
    └── functions/
        └── score-contacts/
            └── index.ts
```

### Swift Packages (SPM)

Add these via File → Add Package Dependencies:

| Package | URL | Version | Purpose |
|---------|-----|---------|---------|
| Supabase Swift | `github.com/supabase/supabase-swift` | `2.x` | All Supabase operations |
| Google Sign-In iOS | `github.com/google/GoogleSignIn-iOS` | `7.x` | Google OAuth |

No other third-party packages needed. Everything else is built on:
- `SFSpeechRecognizer` (Speech.framework)
- `URLSession` (networking)
- `SwiftUI` + `Swift Concurrency`

### Minimum Deployment Target

**iOS 17.0** — required for:
- `@Observable` macro (replaces `@ObservableObject`)
- `NavigationStack` with typed paths
- Swift 5.9 macros
- `SwiftData` (if used for local caching)

### App Capabilities (Xcode)

Enable these in the Ping target → Signing & Capabilities:
- Sign in with Apple
- Push Notifications
- App Groups (shared container with Share Extension: `group.com.yourname.ping`)
- Speech Recognition (for voice capture)

---

## Supabase Setup

### 1. Enable pgvector

In Supabase dashboard → Database → Extensions → enable `vector`.

Or via migration:
```sql
-- 002_enable_pgvector.sql
CREATE EXTENSION IF NOT EXISTS vector;
```

### 2. Run Migrations

Run these SQL files in order in the Supabase SQL editor or via Supabase CLI:

```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Link to your project
supabase login
supabase link --project-ref your-project-ref

# Run migrations
supabase db push
```

### 3. Environment Variables for Edge Functions

```bash
# In Supabase dashboard → Edge Functions → Secrets
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### 4. Schedule the CRON Job

In Supabase dashboard → Edge Functions → create function `score-contacts`, then schedule via pg_cron:

```sql
-- Run at 5pm UTC (9am PST) daily
SELECT cron.schedule(
  'score-contacts-daily',
  '0 17 * * *',
  $$SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/score-contacts',
    headers := '{"Authorization": "Bearer ' || (SELECT value FROM secrets WHERE name = 'SUPABASE_SERVICE_ROLE_KEY') || '"}'::jsonb
  )$$
);
```

---

## iOS Configuration

### Config.swift

```swift
// Config.swift — never commit real values. Use environment or Keychain.

enum Config {
    // Read from Info.plist (injected via xcconfig or Xcode build settings)
    static let supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    static let supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    static let googleClientID = Bundle.main.infoDictionary?["GOOGLE_CLIENT_ID"] as? String ?? ""

    // Gemini API key stored in Keychain (never in plist or source)
    static var geminiAPIKey: String {
        KeychainHelper.get("GEMINI_API_KEY") ?? ""
    }
}
```

### xcconfig Setup (for secrets in build settings)

Create `Config.xcconfig` (add to `.gitignore`):
```
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key
GOOGLE_CLIENT_ID = your-google-client-id
```

Reference in `Info.plist`:
```xml
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key>
<string>$(SUPABASE_ANON_KEY)</string>
<key>GOOGLE_CLIENT_ID</key>
<string>$(GOOGLE_CLIENT_ID)</string>
```

The Gemini API key is NOT in xcconfig — it goes directly into the Keychain. On first launch, if no key is present, show a setup screen: "Paste your Gemini API key to enable AI features."

### KeychainHelper.swift

```swift
struct KeychainHelper {
    static func set(_ key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

---

## Google Cloud Setup

1. Go to console.cloud.google.com → New project "Ping"
2. Enable these APIs:
   - Google People API
   - Google Calendar API
   - Gmail API
   - Google Sign-In (via Firebase Auth or direct OAuth2 — we use direct)
3. Create OAuth 2.0 credentials → iOS application
   - Bundle ID: `com.yourname.ping`
   - Download `GoogleService-Info.plist` → add to Xcode project
4. Configure OAuth consent screen:
   - App name: Ping
   - Scopes: contacts.readonly, calendar.readonly, gmail.readonly
   - Add your Apple ID as a test user for development

---

## Apple Developer Setup

### Sign in with Apple
1. In Apple Developer portal → Certificates, Identifiers & Profiles → Identifiers → your App ID
2. Enable "Sign in with Apple"
3. In Xcode: Signing & Capabilities → + Capability → Sign in with Apple

### Push Notifications
1. Apple Developer portal → Certificates → + → Apple Push Notification service SSL (Sandbox & Production)
2. Download the `.p12` certificate
3. Upload to Supabase: Dashboard → Settings → API → Push Notifications → upload `.p12`

### Share Extension
1. The Share Extension uses the same App ID prefix with `.PingShareExtension` suffix
2. Enable App Groups for both targets (main app + extension)
3. App Group ID: `group.com.yourname.ping`

---

## Git Setup

### .gitignore

```gitignore
# Xcode
*.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
DerivedData/
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.build/
Packages/

# Config (NEVER commit real values)
Config.xcconfig
GoogleService-Info.plist
*.xcconfig

# Supabase
.env
supabase/.temp/

# macOS
.DS_Store
```

### .env (for Supabase CLI, local development only)
```bash
SUPABASE_ACCESS_TOKEN=your-token
```

---

## Development Workflow

### Running Locally

1. Clone the repo
2. Create `Config.xcconfig` with your keys (see above)
3. Add `GoogleService-Info.plist` from Google Cloud Console
4. Open `Ping.xcodeproj` in Xcode
5. Select your development team in Signing & Capabilities
6. Run on device or simulator (iOS 17+ simulator recommended)

### Supabase Local Development

```bash
# Start local Supabase stack
supabase start

# Run migrations
supabase db reset

# Serve Edge Functions locally
supabase functions serve score-contacts --env-file .env
```

### TestFlight Distribution

1. Bump version in Xcode (CFBundleShortVersionString)
2. Archive → Distribute App → TestFlight
3. Add testers in App Store Connect

---

## Environment Summary

| Variable | Where stored | Who needs it |
|----------|-------------|-------------|
| `SUPABASE_URL` | xcconfig (gitignored) | iOS app |
| `SUPABASE_ANON_KEY` | xcconfig (gitignored) | iOS app |
| `GOOGLE_CLIENT_ID` | xcconfig + GoogleService-Info.plist | iOS app |
| `GEMINI_API_KEY` | iOS Keychain (user-entered) | iOS app |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Edge Function secrets | Edge Functions only |
| APNs certificate | Supabase dashboard | Supabase (for push) |
