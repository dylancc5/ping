import SwiftUI
import UniformTypeIdentifiers
import GoogleSignIn

// Tutorial step 2: Import contacts from Google or LinkedIn.
// Reuses the same logic as ProfileTabView but in a streamlined tutorial context.
struct ImportStep: View {

    @ObservedObject var authViewModel: AuthViewModel
    let onNext: () -> Void
    let onSkip: () -> Void

    @Environment(GoogleIntegrationState.self) private var googleState
    @State private var isSigningIn = false
    @State private var isImportingContacts = false
    @State private var importedCount: Int? = nil
    @State private var showLinkedInSheet = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    googleCard
                    linkedInCard

                    if let err = errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(Color.pingDestructive)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                PingButton(title: "Continue →", action: onNext)

                Button("Skip for now") { onSkip() }
                    .font(.subheadline)
                    .foregroundStyle(Color.pingTextMuted)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showLinkedInSheet) {
            LinkedInImportSheetTutorial { count in
                importedCount = (importedCount ?? 0) + count
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import your network")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.pingTextPrimary)
            Text("Start with the people you already know. Import from Google Contacts or LinkedIn.")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
        }
    }

    private var googleCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: googleState.isConnected ? "checkmark.circle.fill" : "person.crop.circle.badge.plus")
                    .font(.system(size: 20))
                    .foregroundStyle(googleState.isConnected ? Color.pingSuccess : Color.pingAccent)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Contacts")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.pingTextPrimary)
                    Text(googleState.isConnected ? googleState.userEmail : "Connect your Google account")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pingTextMuted)
                }

                Spacer()

                if isSigningIn || isImportingContacts {
                    ProgressView()
                } else if googleState.isConnected {
                    Button(importedCount == nil ? "Import" : "Re-import") {
                        Task { await importGoogleContacts() }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.pingAccent)
                } else {
                    Button("Connect") {
                        Task { await signInGoogle() }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.pingAccent)
                }
            }
            .padding(16)

            if let count = importedCount {
                Divider().padding(.leading, 66)
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.pingSuccess)
                        .font(.system(size: 13))
                    Text("\(count) contacts imported")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pingSuccess)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var linkedInCard: some View {
        Button { showLinkedInSheet = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "0A66C2"))
                        .frame(width: 36, height: 36)
                    Text("in")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("LinkedIn Connections")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.pingTextPrimary)
                    Text("Import your connections CSV")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pingTextMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.pingTextSubtle)
            }
            .padding(16)
            .background(Color.pingSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func signInGoogle() async {
        guard let rootVC = rootViewController() else { return }
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            googleState.googleUser = try await GoogleAuthService.signIn(presenting: rootVC)
        } catch {
            errorMessage = "Google sign-in failed: \(error.localizedDescription)"
        }
    }

    private func importGoogleContacts() async {
        guard let user = googleState.googleUser else { return }
        isImportingContacts = true
        defer { isImportingContacts = false }
        do {
            let token = try await GoogleAuthService.getAccessToken(user: user)
            let drafts = try await GoogleContactsService.fetchContacts(accessToken: token)
            let service = SupabaseService.shared
            guard let userId = service.currentUserId else { return }
            let existing = (try? await service.fetchContacts(userId: userId)) ?? []
            let results = LinkedInImportService.classify(drafts: drafts, existing: existing)
            var added = 0
            for result in results {
                switch result {
                case .insert(let draft):
                    if (try? await service.createContact(payload: ContactInsertPayload(draft: draft, userId: userId))) != nil {
                        added += 1
                    }
                case .update(let existingContact, let draft):
                    _ = try? await service.upsertContact(existing: existingContact, draft: draft)
                }
            }
            importedCount = added
            if added > 0 {
                NotificationCenter.default.post(name: .contactsDidImport, object: nil)
            }
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}

// Thin wrapper to reuse the private LinkedInImportSheet from ProfileTabView context
private struct LinkedInImportSheetTutorial: View {
    let onComplete: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var phase: TutorialLinkedInPhase = .idle
    @State private var showFilePicker = false

    enum TutorialLinkedInPhase { case idle, importing, done(Int), failed(String) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()
                switch phase {
                case .idle: instructionsView
                case .importing: progressView
                case .done(let count): doneView(count: count)
                case .failed(let msg): errorView(msg: msg)
                }
            }
            .navigationTitle("Import LinkedIn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.pingAccent)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFile(result)
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pingAccent)
            Text("Export your LinkedIn connections CSV and choose it below.")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                showFilePicker = true
            } label: {
                Label("Choose CSV file", systemImage: "doc.text")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.pingAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private var progressView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.5).tint(Color.pingAccent)
            Text("Importing…")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
            Spacer()
        }
    }

    private func doneView(count: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.pingSuccess)
            Text("\(count) contacts added")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.pingTextPrimary)
            Spacer()
            Button {
                onComplete(count)
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.pingAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func errorView(msg: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pingDestructive)
            Text(msg)
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") { phase = .idle }
                .foregroundStyle(Color.pingAccent)
            Spacer()
        }
    }

    private func handleFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            phase = .failed("Could not open file: \(err.localizedDescription)")
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let drafts = try LinkedInImportService.parseCSV(url)
                guard !drafts.isEmpty else {
                    phase = .failed("No valid contacts found.")
                    return
                }
                phase = .importing
                Task { await runImport(drafts: drafts) }
            } catch {
                phase = .failed("Could not parse CSV: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func runImport(drafts: [ContactDraft]) async {
        let service = SupabaseService.shared
        guard let userId = service.currentUserId else {
            phase = .failed("Please sign in again.")
            return
        }
        let existing = (try? await service.fetchContacts(userId: userId)) ?? []
        let results = LinkedInImportService.classify(drafts: drafts, existing: existing)
        var added = 0
        for result in results {
            switch result {
            case .insert(let draft):
                if (try? await service.createContact(payload: ContactInsertPayload(draft: draft, userId: userId))) != nil {
                    added += 1
                }
            case .update(let existingContact, let draft):
                _ = try? await service.upsertContact(existing: existingContact, draft: draft)
            }
        }
        if added > 0 {
            NotificationCenter.default.post(name: .contactsDidImport, object: nil)
        }
        phase = .done(added)
    }
}
