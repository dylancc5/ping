import GoogleSignIn
import Observation

/// Shared state for Google integration, injected via SwiftUI environment.
/// Holds the signed-in user and results from calendar/Gmail scans so that
/// both ProfileTabView and NetworkTabView can read from the same source.
@Observable
final class GoogleIntegrationState {
    static let shared = GoogleIntegrationState()

    var googleUser: GIDGoogleUser? = nil
    var calendarSuggestions: [CalendarSuggestion] = []
    var gmailSuggestions: [ContactSuggestion] = []

    private init() {}

    var isConnected: Bool { googleUser != nil }
    var userEmail: String { googleUser?.profile?.email ?? "" }
}
