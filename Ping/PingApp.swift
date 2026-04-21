import SwiftUI
import UserNotifications
import GoogleSignIn
import Inject

// MARK: - NotificationRouter

/// Shared observable state that routes a notification tap to the correct nudge.
/// AppDelegate writes targetNudgeId; ContentView reads it to switch tabs and scroll.
@Observable
final class NotificationRouter {
    var targetNudgeId: UUID? = nil

    func navigateToNudge(_ id: UUID) {
        targetNudgeId = id
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    let router = NotificationRouter()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Register the NUDGE category with an "Open Draft" foreground action.
        // Must be registered before any notifications are delivered.
        let openDraftAction = UNNotificationAction(
            identifier: "OPEN_DRAFT",
            title: "Open Draft",
            options: [.foreground]
        )
        let nudgeCategory = UNNotificationCategory(
            identifier: "NUDGE",
            actions: [openDraftAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([nudgeCategory])

        return true
    }

    // MARK: APNs token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { try? await SupabaseService.shared.saveDeviceToken(tokenString) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[AppDelegate] APNs registration failed: \(error)")
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Called when user taps a notification (foreground or background).
    /// Routes to the correct nudge via NotificationRouter.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard
            let nudgeIdString = info["nudge_id"] as? String,
            let nudgeId = UUID(uuidString: nudgeIdString)
        else { return }

        Task {
            try? await SupabaseService.shared.updateNudgeStatus(id: nudgeId, status: .opened)
        }

        await MainActor.run {
            router.navigateToNudge(nudgeId)
        }
    }

    // BACKEND ACTION REQUIRED: The APNs push payload body should be:
    //   nudge.draft_message ?? nudge.reason ?? "Time to reconnect"
    // Currently the Edge Function only sends nudge.reason, which weakens click-through.
    // Update the push Edge Function to prefer draft_message when available.

    /// Called when a notification is about to be presented while the app is in the foreground.
    /// Also marks the nudge as delivered in Supabase.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let info = notification.request.content.userInfo
        if let nudgeIdString = info["nudge_id"] as? String, let nudgeId = UUID(uuidString: nudgeIdString) {
            Task { try? await SupabaseService.shared.updateNudgeStatus(id: nudgeId, status: .delivered) }
        }
        return [.banner, .sound]
    }
}

// MARK: - PingApp

@main
struct PingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    #if DEBUG
    init() {
        _ = InjectConfiguration.load
    }
    #endif

    var body: some Scene {
        WindowGroup {
            rootView
                .task { authViewModel.listenToAuthState() }
                .task { await restoreGoogleSession() }
                .task { await RemoteConfigService.shared.refresh() }
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
    }

    /// Restores the previous Google sign-in from Keychain so Profile tab
    /// integrations (Contacts, Calendar, Gmail) work after a cold relaunch.
    private func restoreGoogleSession() async {
        if let user = try? await GIDSignIn.sharedInstance.restorePreviousSignIn() {
            GoogleIntegrationState.shared.googleUser = user
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if authViewModel.isRestoringSession {
            // Valid local session found but stream hasn't fired yet — show
            // a blank background to avoid flashing WelcomeView on cold launch.
            Color.pingBackground.ignoresSafeArea()
        } else if !authViewModel.isAuthenticated {
            WelcomeView(viewModel: authViewModel)
        } else if !authViewModel.hasToneSamples, !authViewModel.toneCheckFailed, let uid = authViewModel.userId {
            ToneSetupView(userId: uid, viewModel: authViewModel) {
                authViewModel.hasToneSamples = true
            }
        } else {
            ContentView(router: appDelegate.router, authViewModel: authViewModel)
        }
    }
}
