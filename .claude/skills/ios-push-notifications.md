---
name: ios-push-notifications
version: 1.0.0
description: iOS push notification setup — APNs, UserNotifications framework, notification service extensions, rich notifications, and backend integration. Use when implementing push notifications in an iOS app.
---

# iOS Push Notifications Skill

Implement push notifications end-to-end: APNs setup, permissions, handling, rich content, and backend integration.

---

## Setup Overview

```
Backend → APNs → iOS Device → Your App
```

**Two delivery mechanisms:**
- **APNs (Apple Push Notification service)** — for remote pushes from your server
- **UNUserNotificationCenter** — for local notifications and handling all notifications on-device

---

## 1. Capabilities & Entitlements

In Xcode:
1. Select target → Signing & Capabilities
2. Click "+" → **Push Notifications**
3. Also add **Background Modes** → check "Remote notifications"

This creates `MyApp.entitlements`:
```xml
<key>aps-environment</key>
<string>development</string>  <!-- or "production" for App Store -->
```

---

## 2. Request Permission

Request permission early in the app lifecycle (but not at cold launch — wait for a natural moment):

```swift
import UserNotifications

func requestNotificationPermission() async -> Bool {
    let center = UNUserNotificationCenter.current()
    do {
        return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    } catch {
        return false
    }
}

// Check current status without prompting
func notificationStatus() async -> UNAuthorizationStatus {
    await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
}
```

---

## 3. Register for Remote Notifications

In `AppDelegate` or app entry point:

```swift
import UIKit
import UserNotifications

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Called after successful registration
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("APNs token: \(token)")
        // Send token to your backend
        Task { await sendTokenToBackend(token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error)")
    }

    // Handle notification received while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationTap(userInfo: userInfo)
        completionHandler()
    }
}
```

Trigger registration (call after permission granted):
```swift
await UIApplication.shared.registerForRemoteNotifications()
```

---

## 4. APNs Authentication

Two approaches for your backend to authenticate with APNs:

### JWT Token-Based (Recommended)

Generate a JWT signed with your APNs `.p8` key:
- Lasts up to 1 hour (refresh automatically)
- No annual certificate renewal
- One key works for all your apps

```
Authorization: bearer <JWT>
apns-topic: com.example.myapp
```

### Certificate-Based (Legacy)

Download `.p12` from Apple Developer portal. Expires annually.

---

## 5. APNs Payload Structure

```json
{
  "aps": {
    "alert": {
      "title": "New Message",
      "subtitle": "From John",
      "body": "Hey, are you free tonight?"
    },
    "sound": "default",
    "badge": 3,
    "thread-id": "chat-room-123",
    "category": "MESSAGE_REPLY",
    "content-available": 1,
    "mutable-content": 1,
    "interruption-level": "active"
  },
  "custom_data": {
    "conversation_id": "abc123",
    "sender_id": "user456"
  }
}
```

**Key fields:**
| Field | Purpose |
|-------|---------|
| `content-available: 1` | Silent push — wakes app in background |
| `mutable-content: 1` | Allows Notification Service Extension to modify |
| `category` | Links to action buttons |
| `thread-id` | Groups notifications in Notification Center |
| `interruption-level` | `passive`, `active`, `time-sensitive`, `critical` |

---

## 6. Local Notifications

```swift
func scheduleLocalNotification(title: String, body: String, after seconds: Double) async throws {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.badge = 1

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: trigger
    )

    try await UNUserNotificationCenter.current().add(request)
}

// Calendar-based trigger
func scheduleDaily(at hour: Int, minute: Int) async throws {
    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    // ...
}
```

---

## 7. Actionable Notifications

Register categories with actions:

```swift
func registerNotificationCategories() {
    let replyAction = UNTextInputNotificationAction(
        identifier: "REPLY_ACTION",
        title: "Reply",
        options: [],
        textInputButtonTitle: "Send",
        textInputPlaceholder: "Type a message..."
    )

    let markReadAction = UNNotificationAction(
        identifier: "MARK_READ_ACTION",
        title: "Mark as Read",
        options: []
    )

    let messageCategory = UNNotificationCategory(
        identifier: "MESSAGE_REPLY",
        actions: [replyAction, markReadAction],
        intentIdentifiers: [],
        options: .customDismissAction
    )

    UNUserNotificationCenter.current().setNotificationCategories([messageCategory])
}

// Handle action in delegate
func userNotificationCenter(_ center: UNUserNotificationCenter,
                             didReceive response: UNNotificationResponse,
                             withCompletionHandler completionHandler: @escaping () -> Void) {
    switch response.actionIdentifier {
    case "REPLY_ACTION":
        if let textResponse = response as? UNTextInputNotificationResponse {
            let text = textResponse.userText
            Task { await sendReply(text) }
        }
    case "MARK_READ_ACTION":
        Task { await markRead() }
    default:
        // Notification tapped (default action)
        break
    }
    completionHandler()
}
```

---

## 8. Notification Service Extension (Rich Notifications)

Add a **Notification Service Extension** target to modify notifications before display:
- Attach images, audio, or video
- Decrypt end-to-end encrypted content
- Update badge count on delivery

```swift
class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let content = bestAttemptContent,
              let imageURLString = request.content.userInfo["image_url"] as? String,
              let imageURL = URL(string: imageURLString) else {
            contentHandler(request.content)
            return
        }

        // Download and attach image
        downloadAttachment(from: imageURL) { attachment in
            if let attachment {
                content.attachments = [attachment]
            }
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called if time runs out — deliver best attempt
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func downloadAttachment(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        URLSession.shared.downloadTask(with: url) { localURL, _, _ in
            guard let localURL else { completion(nil); return }
            let tmpURL = localURL.deletingLastPathComponent()
                .appendingPathComponent(localURL.lastPathComponent + ".jpg")
            try? FileManager.default.moveItem(at: localURL, to: tmpURL)
            let attachment = try? UNNotificationAttachment(identifier: "image", url: tmpURL)
            completion(attachment)
        }.resume()
    }
}
```

---

## 9. Backend Integration

### Sending via APNs HTTP/2 API

```http
POST /3/device/{deviceToken}
Host: api.push.apple.com
authorization: bearer {JWT}
apns-topic: com.example.myapp
apns-priority: 10
apns-push-type: alert
content-type: application/json

{
  "aps": { "alert": { "title": "Hello", "body": "World" } }
}
```

**Response codes:**
| Code | Meaning |
|------|---------|
| 200 | Success |
| 400 | Bad request (malformed JSON, bad token format) |
| 403 | Certificate/token auth error |
| 410 | Device token invalid — remove from database |
| 429 | Too many requests |
| 500/503 | APNs server error — retry with backoff |

**Important:** Remove `410` tokens from your database immediately.

### Recommended libraries for backend

- **Node.js:** `apn`, `node-apn`
- **Python:** `PyAPNs2`
- **Go:** `sideshow/apns2`
- **Ruby:** `houston`

Or use a managed service: **Firebase Cloud Messaging (FCM)**, **OneSignal**, **AWS SNS**.

---

## 10. Testing

### Simulator (iOS 16+)

```bash
# Send test notification to simulator
xcrun simctl push booted com.example.myapp payload.json

# payload.json
{
  "aps": {
    "alert": { "title": "Test", "body": "Hello from terminal" },
    "sound": "default"
  }
}
```

### Physical Device

Use **Pusher** app (macOS) or **RocketSim** to send test APNs payloads directly from your Mac during development.

### Checklist

- [ ] Permission request shown at appropriate moment (not on cold launch)
- [ ] Device token sent to backend on every launch (token can rotate)
- [ ] `410` tokens removed from backend
- [ ] Foreground presentation behavior configured
- [ ] Deep link routing from notification tap implemented
- [ ] Notification categories registered on every launch
- [ ] Silent push handling implemented if needed (`content-available`)
- [ ] Notification Service Extension added for rich content
