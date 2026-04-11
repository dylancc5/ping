import SwiftUI
import Inject

struct PingButton: View {
    @ObserveInjection var inject
    let title: String
    let action: () -> Void
    var style: ButtonStyle = .primary

    enum ButtonStyle { case primary, secondary, destructive }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(backgroundColor)
                .cornerRadius(14)
        }
        .enableInjection()
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .pingAccent
        case .secondary: return .pingSurface2
        case .destructive: return .pingDestructive
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .pingTextPrimary
        case .destructive: return .white
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PingButton(title: "Save Contact", action: {})
        PingButton(title: "Cancel", action: {}, style: .secondary)
        PingButton(title: "Delete", action: {}, style: .destructive)
    }
    .padding()
}
