import SwiftUI
import AuthenticationServices
import UIKit
import Inject

struct WelcomeView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: AuthViewModel

    private let benefits = [
        "Remember the details that matter",
        "Never miss a follow-up",
        "Stay warm with your network"
    ]

    var body: some View {
        ZStack {
            Color.pingBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                logoSection
                    .padding(.bottom, 20)

                taglineSection
                    .padding(.bottom, 32)

                benefitsSection
                    .padding(.bottom, 56)

                Spacer()

                authButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                footerNote
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
        .alert("Sign-in Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .enableInjection()
    }

    // MARK: - Sections

    private var logoSection: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.pingAccent)
                .frame(width: 48, height: 48)
            Text("Ping")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.pingTextPrimary)
        }
    }

    private var taglineSection: some View {
        Text("Your relationship memory.")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(Color.pingTextPrimary)
            .multilineTextAlignment(.center)
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(benefits, id: \.self) { line in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.pingAccent)
                        .frame(width: 6, height: 6)
                    Text(line)
                        .font(.body)
                        .foregroundStyle(Color.pingTextSecondary)
                }
            }
        }
    }

    private var authButtons: some View {
        VStack(spacing: 12) {
            AppleSignInButton {
                Task { await viewModel.signInWithApple() }
            }
            .frame(height: 52)
            .cornerRadius(14)
            .disabled(viewModel.isLoading)

            googleButton
        }
    }

    private var googleButton: some View {
        Button {
            guard let vc = rootViewController() else { return }
            Task { await viewModel.signInWithGoogle(presenting: vc) }
        } label: {
            HStack(spacing: 10) {
                Text("G")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "4285F4"))
                Text("Continue with Google")
                    .font(.headline)
                    .foregroundStyle(Color.pingTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.pingSurface2)
            .cornerRadius(14)
            .pingCardShadow()
        }
        .disabled(viewModel.isLoading)
    }

    private var footerNote: some View {
        Text("By continuing you agree to our Terms and Privacy Policy.")
            .font(.caption)
            .foregroundStyle(Color.pingTextMuted)
            .multilineTextAlignment(.center)
    }

    // MARK: - Helpers

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}

// MARK: - Apple Sign-In Button Wrapper

private struct AppleSignInButton: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

#Preview {
    WelcomeView(viewModel: AuthViewModel())
}
