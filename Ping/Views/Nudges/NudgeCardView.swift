import SwiftUI
import Inject

struct NudgeCardView: View {
    @ObserveInjection var inject
    let nudge: Nudge
    let contact: Contact
    let onDismiss: () async -> Void
    let onSnooze: (Date) async -> Void
    let onTap: () -> Void

    @State private var showSnoozePicker = false
    @State private var snoozeDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    private var draftPreview: String? {
        guard let draft = nudge.draftMessage, !draft.isEmpty else { return nil }
        if draft.count > 120 {
            return String(draft.prefix(120)) + "…"
        }
        return draft
    }

    private var daysSinceContact: String {
        guard let last = contact.lastContactedAt else { return "a while" }
        let days = Int(Date().timeIntervalSince(last) / 86_400)
        switch days {
        case 0: return "today"
        case 1: return "1 day"
        default: return "\(days) days"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: avatar + name + warmth dot
                HStack(spacing: 10) {
                    ZStack(alignment: .topLeading) {
                        ContactAvatarView(name: contact.name, size: 40)
                        if nudge.status == .delivered || nudge.status == .opened {
                            Circle()
                                .fill(Color.pingAccent)
                                .frame(width: 10, height: 10)
                                .offset(x: -2, y: -2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name)
                            .font(.headline)
                            .foregroundStyle(Color.pingTextPrimary)
                        if let company = contact.company {
                            Text(company)
                                .font(.subheadline)
                                .foregroundStyle(Color.pingTextSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    WarmthDot(score: contact.warmthScore, size: 10)
                }

                // Context line
                Text("Met at \(contact.howMet) · \(daysSinceContact) ago")
                    .font(.caption)
                    .foregroundStyle(Color.pingTextMuted)

                // Draft preview
                if let preview = draftPreview {
                    Text("\"\(preview)\"")
                        .font(.body)
                        .italic()
                        .foregroundStyle(Color.pingTextSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ShimmerBox(height: 13, cornerRadius: 4)
                        ShimmerBox(width: 200, height: 13, cornerRadius: 4)
                        ShimmerBox(width: 140, height: 13, cornerRadius: 4)
                    }
                }

                // CTA button
                HStack {
                    Spacer()
                    Text("Draft message →")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.pingAccent)
                }
            }
            .padding(16)
            .background(Color.pingSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .pingCardShadow()
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                HapticEngine.impact(.light)
                showSnoozePicker = true
            } label: {
                Label("Snooze", systemImage: "bell.slash.fill")
            }
            .tint(Color.pingAccent2)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                HapticEngine.impact(.medium)
                Task { await onDismiss() }
            } label: {
                Label("Dismiss", systemImage: "xmark")
            }
        }
        .sheet(isPresented: $showSnoozePicker) {
            SnoozePickerSheet(snoozeDate: $snoozeDate) { date in
                Task { await onSnooze(date) }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .enableInjection()
    }
}

// MARK: - Snooze Picker Sheet

private struct SnoozePickerSheet: View {
    @Binding var snoozeDate: Date
    let onSnooze: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Snooze until")
                .font(.headline)
                .foregroundStyle(Color.pingTextPrimary)
                .padding(.top, 24)
                .padding(.bottom, 8)

            DatePicker(
                "",
                selection: $snoozeDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color.pingAccent)
            .padding(.horizontal, 8)

            Spacer()

            PingButton(title: "Snooze") {
                onSnooze(snoozeDate)
                dismiss()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color.pingBackground.ignoresSafeArea())
    }
}

// MARK: - Preview

#Preview {
    let nudge = Nudge(
        id: UUID(), contactId: Contact.preview.id, userId: UUID(),
        status: .pending,
        reason: "Haven't talked in 9 days",
        draftMessage: "Hey Marcus, wanted to reach out — it's been a while since we caught up at the SCET fair. Hope the ML infra work at Google is going well!",
        scheduledAt: Date(), deliveredAt: nil, actedAt: nil, snoozedUntil: nil,
        createdAt: Date()
    )
    ScrollView {
        NudgeCardView(
            nudge: nudge,
            contact: .preview,
            onDismiss: {},
            onSnooze: { _ in },
            onTap: {}
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    .background(Color.pingBackground)
}
