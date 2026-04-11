import SwiftUI
import Inject

struct ContactCardGridView: View {
    @ObserveInjection var inject
    let contacts: [Contact]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(contacts) { contact in
                ContactCard(contact: contact)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 80)
        .enableInjection()
    }
}

private struct ContactCard: View {
    let contact: Contact

    private var subtitle: String {
        [contact.company, contact.title]
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 8) {
            ContactAvatarView(name: contact.name, size: 52)

            Text(contact.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.pingTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.pingTextMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            WarmthDot(score: contact.warmthScore, size: 8)

            Text(contact.lastContactedAt.relativeLabel)
                .font(.caption)
                .foregroundStyle(Color.pingTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .pingCardShadow()
    }
}

#Preview {
    ScrollView {
        ContactCardGridView(contacts: .previewSamples)
    }
    .background(Color.pingBackground)
}
