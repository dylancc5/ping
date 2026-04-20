import SwiftUI
import UIKit
import Inject

struct MessageDraftView: View {
    @ObserveInjection var inject
    let nudge: Nudge
    let contact: Contact
    let pingViewModel: PingViewModel

    @State private var vm = ContactViewModel()
    @State private var draftText: String
    @State private var isRegenerating = false
    @State private var isGeneratingInitialDraft = false
    @State private var copiedFeedback = false
    @State private var missingInfoAlert: MissingInfoAlert? = nil
    @State private var showEditContact = false
    @State private var regenerateError: Bool = false
    @State private var showSuccessOverlay = false
    @State private var selectedTone: DraftTone? = nil
    @State private var showAIFallbackBanner = false
    @FocusState private var editorFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(nudge: Nudge, contact: Contact, pingViewModel: PingViewModel) {
        self.nudge = nudge
        self.contact = contact
        self.pingViewModel = pingViewModel
        _draftText = State(initialValue: nudge.draftMessage ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        contactContextCard
                        draftEditorCard
                        if showAIFallbackBanner {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.pingWarmthCool)
                                Text("AI unavailable — here's a template to start from")
                                    .font(.caption)
                                    .foregroundStyle(Color.pingTextMuted)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.pingSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        toneChipRow
                        regenerateButton
                        sendActionsRow
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }

                if showSuccessOverlay {
                    VStack(spacing: 16) {
                        Text("🎉")
                            .font(.system(size: 56))
                        Text("Sent to \(contact.name.components(separatedBy: " ").first ?? contact.name)!")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.pingTextPrimary)
                        Text("Next best time: ~\(max(7, Int(contact.warmthScore * 20))) days")
                            .font(.subheadline)
                            .foregroundStyle(Color.pingTextMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.pingBackground.opacity(0.97))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(1)
                }
            }
            .navigationTitle(contact.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        saveDraftIfNeeded()
                        dismiss()
                    }
                        .foregroundStyle(Color.pingAccent)
                }
            }
            .task {
                await vm.load(contactId: contact.id)
                await prefillDraftIfNeeded()
            }
            .alert(item: $missingInfoAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Edit Contact")) { showEditContact = true },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showEditContact) {
                EditContactSheet(contact: contact, onSave: { _ in showEditContact = false })
            }
            .alert("Couldn't Regenerate", isPresented: $regenerateError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Failed to generate a new draft. Check your API key or try again.")
            }
        }
        .enableInjection()
    }

    // MARK: - Contact Context Card

    private var contactContextCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ContactAvatarView(name: contact.name, size: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(contact.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.pingTextPrimary)

                    let subtitle = [contact.title, contact.company]
                        .compactMap { $0 }
                        .joined(separator: " at ")
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.pingTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                WarmthDot(score: contact.warmthScore, size: 12)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                contextRow(icon: "mappin.circle.fill", text: "Met at \(contact.howMet)")

                if let last = contact.lastContactedAt {
                    let days = Int(Date().timeIntervalSince(last) / 86_400)
                    let label = days == 0 ? "Today" : days == 1 ? "1 day ago" : "\(days) days ago"
                    contextRow(icon: "clock.fill", text: "Last contact: \(label)")
                } else {
                    contextRow(icon: "clock.fill", text: "No contact logged yet")
                }

                if let reason = nudge.reason {
                    contextRow(icon: "bell.fill", text: reason)
                }
            }
        }
        .padding(16)
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .pingCardShadow()
    }

    @ViewBuilder
    private func contextRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.pingAccent)
                .frame(width: 16)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
        }
    }

    // MARK: - Draft Editor Card

    private var draftEditorCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Your message")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.pingTextMuted)
                    .tracking(0.4)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 14)

            TextEditor(text: $draftText)
                .font(.body)
                .foregroundStyle(Color.pingTextPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 180)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .focused($editorFocused)

            Divider()
                .padding(.horizontal, 14)

            HStack {
                Spacer()
                Text("\(draftText.count) chars")
                    .font(.caption)
                    .foregroundStyle(Color.pingTextSubtle)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    Color.pingAccent.opacity(editorFocused ? 0.35 : 0),
                    lineWidth: 1.5
                )
                .animation(.easeInOut(duration: 0.2), value: editorFocused)
        )
        .pingCardShadow()
    }

    // MARK: - Regenerate Button

    private var toneChipRow: some View {
        HStack(spacing: 8) {
            ForEach(DraftTone.allCases) { tone in
                let isSelected = selectedTone == tone
                Button {
                    HapticEngine.impact(.light)
                    selectedTone = tone
                    regenerate()
                } label: {
                    HStack(spacing: 4) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                        }
                        Text(tone.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.pingAccent : Color.pingSurface2)
                    .foregroundStyle(isSelected ? Color.white : Color.pingTextSecondary)
                    .clipShape(Capsule())
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }
            }
            Spacer()
        }
    }

    private var regenerateButton: some View {
        Button(action: regenerate) {
            HStack(spacing: 8) {
                if isRegenerating || isGeneratingInitialDraft {
                    ProgressView()
                        .scaleEffect(0.85)
                        .tint(Color.pingAccent)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                Text((isRegenerating || isGeneratingInitialDraft) ? "Finding a new tone…" : "Try a different tone")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle((isRegenerating || isGeneratingInitialDraft) ? Color.pingTextMuted : Color.pingAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.pingSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .pingCardShadow()
        }
        .disabled(isRegenerating || isGeneratingInitialDraft)
        .animation(.easeInOut(duration: 0.15), value: isRegenerating || isGeneratingInitialDraft)
    }

    // MARK: - Send Actions Row

    private var sendActionsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send via")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.pingTextMuted)
                .tracking(0.4)
                .padding(.horizontal, 2)

            HStack(spacing: 10) {
                sendButton(
                    icon: "message.fill",
                    label: "iMessage",
                    isConfirmed: false
                ) {
                    sendViaiMessage()
                }

                sendButton(
                    icon: "envelope.fill",
                    label: "Email",
                    isConfirmed: false
                ) {
                    sendViaEmail()
                }

                sendButton(
                    icon: "link",
                    label: "LinkedIn",
                    isConfirmed: false
                ) {
                    sendViaLinkedIn()
                }

                sendButton(
                    icon: copiedFeedback ? "checkmark" : "doc.on.doc.fill",
                    label: copiedFeedback ? "Copied!" : "Copy",
                    isConfirmed: copiedFeedback
                ) {
                    copyToClipboard()
                }
            }
        }
    }

    @ViewBuilder
    private func sendButton(icon: String, label: String, isConfirmed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isConfirmed ? Color.pingSuccess : Color.pingAccent)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isConfirmed ? Color.pingSuccess : Color.pingTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(isConfirmed ? Color.pingSuccessLight : Color.pingSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.2), value: isConfirmed)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Send Actions

    private func sendViaiMessage() {
        guard let phone = contact.phone, !phone.isEmpty else {
            missingInfoAlert = MissingInfoAlert(
                title: "No Phone Number",
                message: "Add a phone number to \(contact.name)'s contact to message them."
            )
            return
        }
        let encoded = draftText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "sms:\(phone)&body=\(encoded)") {
            UIApplication.shared.open(url)
            onSendAction()
        }
    }

    private func sendViaEmail() {
        guard let email = contact.email, !email.isEmpty else {
            missingInfoAlert = MissingInfoAlert(
                title: "No Email Address",
                message: "Add an email address to \(contact.name)'s contact to email them."
            )
            return
        }
        let encoded = draftText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(email)?body=\(encoded)") {
            UIApplication.shared.open(url)
            onSendAction()
        }
    }

    private func sendViaLinkedIn() {
        // Try LinkedIn app deep link to compose first, fall back to profile URL + copy.
        if let handle = extractLinkedInHandle(from: contact.linkedinUrl),
           let deepLink = URL(string: "linkedin://messaging/compose?recipient=\(handle)"),
           UIApplication.shared.canOpenURL(deepLink) {
            UIPasteboard.general.string = draftText
            UIApplication.shared.open(deepLink)
            onSendAction()
        } else if let linkedinUrl = contact.linkedinUrl,
                  !linkedinUrl.isEmpty,
                  let url = URL(string: linkedinUrl) {
            UIPasteboard.general.string = draftText
            UIApplication.shared.open(url)
            onSendAction()
        } else {
            UIPasteboard.general.string = draftText
            missingInfoAlert = MissingInfoAlert(
                title: "Message Copied",
                message: "No LinkedIn URL saved for \(contact.name). Your message has been copied — open LinkedIn to paste it."
            )
        }
    }

    private func extractLinkedInHandle(from urlString: String?) -> String? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        let components = url.pathComponents
        guard let inIdx = components.firstIndex(of: "in"),
              components.index(after: inIdx) < components.endIndex else { return nil }
        return components[components.index(after: inIdx)]
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = draftText
        saveDraftIfNeeded()
        HapticEngine.impact(.light)
        withAnimation { copiedFeedback = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copiedFeedback = false }
        }
    }

    private func onSendAction() {
        Task {
            await pingViewModel.markNudgeActed(nudge)
            await vm.logInteraction(type: .nudgeSent)
            if draftText != (nudge.draftMessage ?? "") {
                await vm.saveNudgeDraft(nudge, draft: draftText)
            }
            HapticEngine.success()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showSuccessOverlay = true
            }
            try? await Task.sleep(for: .seconds(2.5))
            dismiss()
        }
    }

    private func regenerate() {
        isRegenerating = true
        Task {
            defer { isRegenerating = false }
            if let newDraft = await vm.generateDraft(
                contact: contact,
                nudgeReason: nudge.reason ?? "General check-in",
                forceRefresh: true,
                tone: selectedTone
            ) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    draftText = newDraft
                }
            } else {
                regenerateError = true
            }
        }
    }

    private func prefillDraftIfNeeded() async {
        guard draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isGeneratingInitialDraft = true
        defer { isGeneratingInitialDraft = false }
        if let generated = await vm.generateDraft(
            contact: contact,
            nudgeReason: nudge.reason ?? "General check-in"
        ) {
            draftText = generated
            await vm.saveNudgeDraft(nudge, draft: generated)
        } else {
            draftText = fallbackTemplate(for: contact)
            showAIFallbackBanner = true
        }
    }

    private func fallbackTemplate(for contact: Contact) -> String {
        let firstName = contact.name.components(separatedBy: " ").first ?? contact.name
        switch contact.warmthScore {
        case 0.7...:
            return "Hey \(firstName), been a while! Hope everything's going well — would love to catch up soon."
        case 0.4..<0.7:
            return "Hi \(firstName), wanted to reach out and see how things are going. It's been a bit since we last connected!"
        default:
            return "Hi \(firstName), came across something that made me think of you — hope you're doing well. Would love to reconnect."
        }
    }

    private func saveDraftIfNeeded() {
        guard draftText != (nudge.draftMessage ?? ""), !draftText.isEmpty else { return }
        Task {
            await vm.saveNudgeDraft(nudge, draft: draftText)
        }
    }
}

// MARK: - Alert Model

private struct MissingInfoAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - Preview

#Preview {
    @Previewable @State var vm = PingViewModel()
    let nudge = Nudge(
        id: UUID(), contactId: Contact.preview.id, userId: UUID(),
        status: .pending,
        reason: "Haven't talked in 9 days",
        draftMessage: "Hey Marcus, it's been a while — hope the ML infra work at Google is going well! Would love to grab coffee sometime and hear what you've been up to.",
        scheduledAt: Date(), deliveredAt: nil, actedAt: nil, snoozedUntil: nil,
        createdAt: Date()
    )

    return MessageDraftView(nudge: nudge, contact: .preview, pingViewModel: vm)
}
