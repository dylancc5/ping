import SwiftUI
import Inject

struct ContactAvatarView: View {
    @ObserveInjection var inject
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return "\(words.first!.prefix(1))\(words.last!.prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        Circle()
            .fill(Color.pingAccentLight)
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.pingAccent)
            }
            .enableInjection()
    }
}

#Preview {
    HStack(spacing: 12) {
        ContactAvatarView(name: "Marcus Chen")
        ContactAvatarView(name: "Sarah Kim", size: 56)
        ContactAvatarView(name: "Alex")
    }
    .padding()
}
