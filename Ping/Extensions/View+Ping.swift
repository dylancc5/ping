import SwiftUI

private struct PingCardShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let radius: CGFloat
    let y: CGFloat
    let lightOpacity: Double
    let darkOpacity: Double

    func body(content: Content) -> some View {
        let opacity = colorScheme == .dark ? darkOpacity : lightOpacity
        content.shadow(color: Color.black.opacity(opacity), radius: radius, x: 0, y: y)
    }
}

extension Notification.Name {
    static let contactsDidImport = Notification.Name("pingContactsDidImport")
    static let showQuickCapture  = Notification.Name("pingShowQuickCapture")
}

extension View {
    func pingCardShadow() -> some View {
        modifier(PingCardShadowModifier(radius: 8, y: 2, lightOpacity: 0.06, darkOpacity: 0.0))
    }

    func pingSoftShadow() -> some View {
        modifier(PingCardShadowModifier(radius: 4, y: 1, lightOpacity: 0.04, darkOpacity: 0.0))
    }

    func userFacingMessage(for error: Error) -> String {
        let desc = error.localizedDescription.lowercased()
        if desc.contains("offline") || desc.contains("network") || desc.contains("internet")
            || desc.contains("connection") || desc.contains("timed out") || desc.contains("timeout") {
            return "Check your connection and try again."
        }
        if desc.contains("401") || desc.contains("unauthorized") || desc.contains("token")
            || desc.contains("session") || desc.contains("sign") {
            return "Session expired. Please sign in again."
        }
        return "Something went wrong. Pull to refresh."
    }
}
