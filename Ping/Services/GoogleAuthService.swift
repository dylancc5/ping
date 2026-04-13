import GoogleSignIn
import UIKit

struct GoogleAuthService {
    struct IDTokenInfo {
        let token: String
        let nonce: String?
    }

    private static let scopes = [
        "https://www.googleapis.com/auth/contacts.readonly",
        "https://www.googleapis.com/auth/calendar.readonly",
        "https://www.googleapis.com/auth/gmail.readonly"
    ]

    /// Signs in with Google, requesting Contacts, Calendar, and Gmail read scopes.
    @MainActor
    static func signIn(presenting viewController: UIViewController) async throws -> GIDGoogleUser {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: Config.googleClientID)
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

    /// Returns a fresh ID token (JWT) and optional nonce claim.
    /// Required for Supabase Google sign-in via signInWithIdToken.
    static func getIDTokenInfo(user: GIDGoogleUser) async throws -> IDTokenInfo {
        try await user.refreshTokensIfNeeded()
        guard let idToken = user.idToken?.tokenString else {
            throw URLError(.userAuthenticationRequired)
        }
        return IDTokenInfo(token: idToken, nonce: nonceClaim(from: idToken))
    }

    static func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    private static func nonceClaim(from jwt: String) -> String? {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder > 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object["nonce"] as? String
    }
}
