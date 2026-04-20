import Foundation
import AuthenticationServices
import UIKit

@MainActor
final class AuthViewModel: NSObject, ObservableObject {

    @Published var isAuthenticated: Bool = SupabaseService.shared.hasValidLocalSession
    @Published var userId: UUID? = nil
    @Published var hasToneSamples: Bool = false
    @Published var toneCheckFailed: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    /// True while we know a valid local session exists but the auth stream
    /// hasn't yet fired its initial .signedIn event. Prevents a flash of
    /// WelcomeView on cold launch for already-authenticated users.
    @Published var isRestoringSession: Bool = SupabaseService.shared.hasValidLocalSession

    private var appleSignInContinuation: CheckedContinuation<ASAuthorization, Error>?

    // MARK: - Auth State Listener

    func listenToAuthState() {
        // Safety timeout: if the auth stream doesn't resolve within 2 seconds,
        // clear isRestoringSession so the user never gets a permanent white screen.
        Task {
            try? await Task.sleep(for: .seconds(2))
            if isRestoringSession {
                isRestoringSession = false
            }
        }

        Task {
            for await (event, session) in await SupabaseService.shared.authStateChanges {
                switch event {
                case .signedIn, .initialSession:
                    if session?.isExpired == true {
                        isRestoringSession = false
                        break
                    }
                    let uid = session?.user.id
                    userId = uid
                    isAuthenticated = uid != nil
                    isRestoringSession = false
                    if let uid {
                        await checkToneSamples(userId: uid)
                    }
                case .signedOut:
                    userId = nil
                    isAuthenticated = false
                    hasToneSamples = false
                    toneCheckFailed = false
                    isRestoringSession = false
                    GoogleIntegrationState.shared.googleUser = nil
                    GoogleIntegrationState.shared.calendarSuggestions = []
                    GoogleIntegrationState.shared.gmailSuggestions = []
                case .tokenRefreshed:
                    // Keep Share Extension tokens current so it doesn't get 401s after rotation.
                    await SupabaseService.shared.persistSessionForExtension()
                    isRestoringSession = false
                default:
                    isRestoringSession = false
                }
            }
        }
    }

    // MARK: - Apple Sign-In

    func signInWithApple() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let authorization = try await withCheckedThrowingContinuation { continuation in
                self.appleSignInContinuation = continuation
                let provider = ASAuthorizationAppleIDProvider()
                let request = provider.createRequest()
                request.requestedScopes = [.fullName, .email]
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = appleCredential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8) else {
                throw URLError(.badServerResponse)
            }
            try await SupabaseService.shared.signInWithApple(idToken: tokenString)
        } catch {
            // Ignore user-cancelled errors
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                errorMessage = Self.userFacingAuthError(error)
            }
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle(presenting viewController: UIViewController) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await GoogleAuthService.signIn(presenting: viewController)
            async let idTokenInfoFetch = GoogleAuthService.getIDTokenInfo(user: user)
            async let accessTokenFetch = GoogleAuthService.getAccessToken(user: user)
            let (idTokenInfo, accessToken) = try await (idTokenInfoFetch, accessTokenFetch)
            // Persist for Profile tab integrations (contacts, calendar, gmail)
            GoogleIntegrationState.shared.googleUser = user
            try await SupabaseService.shared.signInWithGoogle(
                idToken: idTokenInfo.token,
                accessToken: accessToken,
                nonce: idTokenInfo.nonce
            )
        } catch {
            errorMessage = Self.userFacingAuthError(error)
        }
    }

    private static func userFacingAuthError(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("invalid api key") {
            return "Supabase rejected the API key. In the dashboard open Settings → API, copy the Project URL host and anon public key into Config.xcconfig, then Product → Clean Build Folder and run again."
        }
        return text
    }

    // MARK: - Tone Samples

    func checkToneSamples(userId: UUID) async {
        do {
            hasToneSamples = try await SupabaseService.shared.hasToneSamples(userId: userId)
            toneCheckFailed = false
        } catch {
            hasToneSamples = false
            toneCheckFailed = true
        }
    }

    func saveToneSample(_ text: String) async {
        guard let uid = userId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await SupabaseService.shared.saveToneSample(text, userId: uid)
            hasToneSamples = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthViewModel: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            appleSignInContinuation?.resume(returning: authorization)
            appleSignInContinuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            appleSignInContinuation?.resume(throwing: error)
            appleSignInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                if let key = scene.windows.first(where: \.isKeyWindow) { return key }
            }
            if let first = scenes.first?.windows.first { return first }
            return UIWindow()
        }
    }
}
