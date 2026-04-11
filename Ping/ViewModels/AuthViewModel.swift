import Foundation
import AuthenticationServices
import UIKit

@MainActor
final class AuthViewModel: NSObject, ObservableObject {

    @Published var isAuthenticated: Bool = false
    @Published var userId: UUID? = nil
    @Published var hasToneSamples: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var appleSignInContinuation: CheckedContinuation<ASAuthorization, Error>?

    // MARK: - Auth State Listener

    func listenToAuthState() {
        Task {
            for await (event, session) in await SupabaseService.shared.authStateChanges {
                switch event {
                case .signedIn:
                    let uid = session?.user.id
                    userId = uid
                    isAuthenticated = true
                    if let uid {
                        await checkToneSamples(userId: uid)
                    }
                case .signedOut:
                    userId = nil
                    isAuthenticated = false
                    hasToneSamples = false
                default:
                    break
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
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle(presenting viewController: UIViewController) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await GoogleAuthService.signIn(presenting: viewController)
            async let idTokenFetch = GoogleAuthService.getIDToken(user: user)
            async let accessTokenFetch = GoogleAuthService.getAccessToken(user: user)
            let (idToken, accessToken) = try await (idTokenFetch, accessTokenFetch)
            // Persist for Profile tab integrations (contacts, calendar, gmail)
            GoogleIntegrationState.shared.googleUser = user
            try await SupabaseService.shared.signInWithGoogle(idToken: idToken, accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Tone Samples

    func checkToneSamples(userId: UUID) async {
        do {
            hasToneSamples = try await SupabaseService.shared.hasToneSamples(userId: userId)
        } catch {
            hasToneSamples = false
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
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first(where: \.isKeyWindow) ?? UIWindow()
    }
}
