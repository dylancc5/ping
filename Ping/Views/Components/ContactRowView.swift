import SwiftUI
import Inject

struct ContactRowView: View {
    @ObserveInjection var inject
    let contact: Contact

    private var subtitle: String {
        [contact.company, contact.title]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            ContactAvatarView(name: contact.name, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.headline)
                    .foregroundStyle(Color.pingTextPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(contact.lastContactedAt.relativeLabel)
                    .font(.caption)
                    .foregroundStyle(Color.pingTextMuted)
                WarmthDot(score: contact.warmthScore, size: 8)
            }
        }
        .padding(.vertical, 12)
        .enableInjection()
    }
}

#Preview {
    List {
        ContactRowView(contact: .preview)
        ContactRowView(contact: .previewCold)
    }
    .listStyle(.plain)
}
