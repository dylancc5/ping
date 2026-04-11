import SwiftUI
import Inject

struct ContactDetailView: View {
    @ObserveInjection var inject
    let contact: Contact
    var interactions: [Interaction] = []

    @State private var isDraftLoading = true
    @State private var showMessageDraft = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                    .padding(.bottom, 24)

                draftCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                contextSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                historySection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
            .padding(.top, 24)
        }
        .background(Color.pingBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { }
                    .foregroundStyle(Color.pingAccent)
            }
        }
        .sheet(isPresented: $showMessageDraft) {
            MessageDraftView()
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { isDraftLoading = false }
            }
        }
        .enableInjection()
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ContactAvatarView(name: contact.name, size: 72)
                WarmthDot(score: contact.warmthScore, size: 12)
                    .offset(x: 4, y: -4)
            }

            Text(contact.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.pingTextPrimary)

            if let company = contact.company, let title = contact.title {
                Text("\(company) · \(title)")
                    .font(.subheadline)
                    .foregroundStyle(Color.pingTextSecondary)
            } else if let company = contact.company {
                Text(company)
                    .font(.subheadline)
                    .foregroundStyle(Color.pingTextSecondary)
            }

            Text(warmthLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(warmthColor)

            HStack(spacing: 20) {
                if let email = contact.email {
                    Link(destination: URL(string: "mailto:\(email)")!) {
                        Image(systemName: "envelope.fill")
                            .font(.title3)
                            .foregroundStyle(Color.pingTextMuted)
                    }
                }
                if contact.linkedinUrl != nil {
                    Button { } label: {
                        Image(systemName: "person.crop.square.filled.and.at.rectangle")
                            .font(.title3)
                            .foregroundStyle(Color.pingTextMuted)
                    }
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Draft Card

    private var draftCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Message")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.pingTextMuted)
                .textCase(.uppercase)
                .tracking(0.5)

            if isDraftLoading {
                VStack(alignment: .leading, spacing: 8) {
                    ShimmerBox(height: 14, cornerRadius: 6)
                    ShimmerBox(width: 220, height: 14, cornerRadius: 6)
                    ShimmerBox(width: 160, height: 14, cornerRadius: 6)
                }
                Text("Generating draft...")
                    .font(.caption)
                    .foregroundStyle(Color.pingTextMuted)
            } else {
                Text("\"Hey \(contact.name.split(separator: " ").first.map(String.init) ?? contact.name), been a while — would love to catch up and hear how things are going at \(contact.company ?? "your new role"). Coffee next week?\"")
                    .font(.body)
                    .italic()
                    .foregroundStyle(Color.pingTextPrimary)
            }

            PingButton(title: "Edit & Send →", style: .primary) {
                showMessageDraft = true
            }

            Button {
                isDraftLoading = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation { isDraftLoading = false }
                }
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .foregroundStyle(Color.pingAccent)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .pingCardShadow()
    }

    // MARK: - Context Section

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Context")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.pingTextMuted)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                contextRow(icon: "mappin.circle.fill", label: "How we met", value: contact.howMet)
                Divider().padding(.leading, 44)
                if let metAt = contact.metAt {
                    contextRow(icon: "calendar", label: "Date met", value: metAt.shortFormatted)
                    Divider().padding(.leading, 44)
                }
                if let notes = contact.notes {
                    contextRow(icon: "note.text", label: "Notes", value: notes)
                    Divider().padding(.leading, 44)
                }
                if !contact.tags.isEmpty {
                    contextRow(icon: "tag.fill", label: "Tags", value: contact.tags.map { "#\($0)" }.joined(separator: "  "))
                }
            }
            .background(Color.pingSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func contextRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.pingTextMuted)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.pingTextMuted)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Color.pingTextPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.pingTextMuted)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                if interactions.isEmpty {
                    Text("No interactions yet.")
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(20)
                } else {
                    let sorted = interactions.sorted { $0.occurredAt < $1.occurredAt }
                    ForEach(sorted) { interaction in
                        interactionRow(interaction)
                        if interaction.id != sorted.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Button {
                    } label: {
                        Label("Add Note", systemImage: "note.text.badge.plus")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .foregroundStyle(Color.pingAccent)

                    Divider().frame(height: 20)

                    Button {
                    } label: {
                        Label("Log Interaction", systemImage: "plus.circle")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .foregroundStyle(Color.pingAccent)
                }
                .padding(.horizontal, 16)
            }
            .background(Color.pingSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func interactionRow(_ interaction: Interaction) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: interaction.type.icon)
                .font(.subheadline)
                .foregroundStyle(Color.pingTextMuted)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(interaction.type.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pingTextPrimary)
                if let notes = interaction.notes {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextSecondary)
                }
            }

            Spacer()

            Text(interaction.occurredAt.relativeLabel)
                .font(.caption)
                .foregroundStyle(Color.pingTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Warmth helpers

    private var warmthLabel: String {
        switch contact.warmthScore {
        case 0.8...: return "Hot"
        case 0.5..<0.8: return "Warm"
        case 0.2..<0.5: return "Cool"
        default: return "Cold"
        }
    }

    private var warmthColor: Color {
        switch contact.warmthScore {
        case 0.8...: return .pingWarmthHot
        case 0.5..<0.8: return .pingWarmthWarm
        case 0.2..<0.5: return .pingWarmthCool
        default: return .pingWarmthCold
        }
    }
}

#Preview {
    NavigationStack {
        ContactDetailView(contact: .preview)
    }
}
