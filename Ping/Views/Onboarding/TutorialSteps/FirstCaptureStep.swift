import SwiftUI

// Tutorial step 4: Capture your first contact via QuickCaptureView.
// After saving, shows the generated autodraft as the "aha" moment.
struct FirstCaptureStep: View {

    @ObservedObject var authViewModel: AuthViewModel
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var showCapture = false
    @State private var capturedContact: Contact? = nil
    @State private var networkVM = NetworkViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.pingAccent)

                VStack(spacing: 8) {
                    Text("Capture your first contact")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.pingTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Hold the mic and say who you met and where. Ping will pull out the details automatically.")
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            if let contact = capturedContact {
                successCard(contact: contact)
                    .padding(.horizontal, 20)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                Spacer()
            }

            VStack(spacing: 12) {
                if capturedContact == nil {
                    PingButton(title: "Capture a contact →") {
                        showCapture = true
                    }
                } else {
                    PingButton(title: "Continue →", action: onNext)
                }

                Button("Skip for now") { onSkip() }
                    .font(.subheadline)
                    .foregroundStyle(Color.pingTextMuted)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showCapture) {
            QuickCaptureView(viewModel: networkVM)
                .presentationDetents([.large])
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidImport)) { _ in
            // QuickCaptureView posts this after save; load the newest contact to show the aha moment.
            Task {
                await networkVM.loadContacts()
                if let newest = networkVM.contacts.sorted(by: { $0.createdAt > $1.createdAt }).first {
                    withAnimation(.spring(duration: 0.4)) {
                        capturedContact = newest
                    }
                }
            }
        }
    }

    private func successCard(contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ContactAvatarView(name: contact.name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.pingTextPrimary)
                    if let company = contact.company {
                        Text(company)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pingTextMuted)
                    }
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.pingSuccess)
                    .font(.system(size: 18))
            }

            Text("Contact saved! Ping will draft a message for you in the background.")
                .font(.caption)
                .foregroundStyle(Color.pingTextMuted)
        }
        .padding(16)
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
