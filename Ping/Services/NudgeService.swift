import Foundation
import UserNotifications
import UIKit

// MARK: - NudgeService
//
// Manages local notification scheduling and permission requests.
// Remote (APNs) push notifications are sent by the score-contacts Edge Function.
// This service provides:
//   1. Permission request — triggered on first nudge load, not on app launch.
//   2. Local notification fallback — schedules UNUserNotificationRequests so the
//      full nudge tap flow can be tested without APNs certificates configured.

actor NudgeService {
    static let shared = NudgeService()

    private init() {}

    // MARK: - Permission

    /// Request notification authorization if the user hasn't been asked yet.
    /// No-op when already granted or denied. Call this the first time nudges are loaded.
    func requestNotificationPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            print("[NudgeService] Notification permission error: \(error)")
        }
    }

    // MARK: - Local Notification Fallback

    /// Schedule a local notification for a nudge.
    /// Used during MVP development before APNs certificates are configured.
    /// Payload format mirrors what the Edge Function sends via APNs so that
    /// the AppDelegate tap handler works identically for both paths.
    func scheduleLocalNotification(
        nudgeId: UUID,
        contactId: UUID,
        contactName: String,
        body: String,
        at date: Date
    ) async {
        let content = UNMutableNotificationContent()
        content.title = contactName
        content.body = String(body.prefix(80))
        content.categoryIdentifier = "NUDGE"
        content.userInfo = [
            "nudge_id": nudgeId.uuidString,
            "contact_id": contactId.uuidString,
        ]
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: nudgeId.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("[NudgeService] Failed to schedule local notification for nudge \(nudgeId): \(error)")
        }
    }

    /// Cancel a previously scheduled local notification (e.g. when user dismisses or snoozes).
    func cancelLocalNotification(nudgeId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [nudgeId.uuidString]
        )
    }
}
