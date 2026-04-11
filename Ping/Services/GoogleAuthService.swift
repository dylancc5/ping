import GoogleSignIn
import UIKit

struct GoogleAuthService {

    private static let scopes = [
        "https://www.googleapis.com/auth/contacts.readonly",
        "https://www.googleapis.com/auth/calendar.readonly",
        "https://www.googleapis.com/auth/gmail.readonly"
    ]

    /// Signs in with Google, requesting Contacts, Calendar, and Gmail read scopes.
    static func signIn(presenting viewController: UIViewController) async throws -> GIDGoogleUser {
        let config = GIDConfiguration(clientID: Config.googleClientID)
        GIDSignIn.sharedInstance.configuration = config

        return try await GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            hint: nil,
            additionalScopes: scopes
        ).user
    }

    /// Returns a fresh access token, refreshing if needed.
    static func getAccessToken(user: GIDGoogleUser) async throws -> String {
        try await user.refreshTokensIfNeeded()
        return user.accessToken.tokenString
    }

    /// Restores a previous sign-in session, if one exists.
    static func restorePreviousSignIn() async -> GIDGoogleUser? {
        try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
    }

    /// Returns a fresh ID token (JWT), refreshing credentials if needed.
    /// Required for Supabase Google sign-in via signInWithIdToken.
    static func getIDToken(user: GIDGoogleUser) async throws -> String {
        try await user.refreshTokensIfNeeded()
        guard let idToken = user.idToken?.tokenString else {
            throw URLError(.userAuthenticationRequired)
        }
        return idToken
    }

    static func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}
