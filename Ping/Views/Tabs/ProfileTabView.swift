import SwiftUI
import UniformTypeIdentifiers
import GoogleSignIn
import Inject

// MARK: - Import State

private enum ImportPhase: Equatable {
    case idle
    case preview(drafts: [ContactDraft], skipped: Int)
    case importing(current: Int, total: Int)
    case done(imported: Int, skipped: Int)
    case failed(String)

    static func == (lhs: ImportPhase, rhs: ImportPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case let (.preview(d1, s1), .preview(d2, s2)): return d1.count == d2.count && s1 == s2
        case let (.importing(c1, t1), .importing(c2, t2)): return c1 == c2 && t1 == t2
        case let (.done(i1, s1), .done(i2, s2)): return i1 == i2 && s1 == s2
        case let (.failed(e1), .failed(e2)): return e1 == e2
        default: return false
        }
    }
}

// MARK: - ProfileTabView

struct ProfileTabView: View {
    @ObserveInjection var inject
    @Environment(GoogleIntegrationState.self) private var googleState
    @ObservedObject var authViewModel: AuthViewModel

    @State private var showLinkedInSheet = false
    @State private var showToneSettingsSheet = false
    @State private var showGeminiKeySheet = false
    @State private var isBackfillingEmbeddings = false
    @State private var backfillResult: String? = nil
    private var linkedInCountKey: String {
        "linkedinImportCount_\(authViewModel.userId?.uuidString ?? "anon")"
    }
    @State private var importedCount = 0
    @State private var aiHeaderTapCount = 0
    @State private var showDeveloperTools = false
    @State private var showSignOutConfirm = false

    // Google state
    @State private var isSigningIn = false
    @State private var isScanningCalendar = false
    @State private var isScanningGmail = false
    @State private var isImportingContacts = false
    @State private var contactsImportCount: Int? = nil
    @State private var showCalendarSuggestions = false
    @State private var googleErrorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionHeader("ACCOUNT")
                        accountSection

                        sectionHeader("INTEGRATIONS")

                        googleSection
                        linkedInRow

                        sectionHeader("AI")
                            .onTapGesture {
                                aiHeaderTapCount += 1
                                if aiHeaderTapCount >= 5 {
                                    showDeveloperTools = true
                                    aiHeaderTapCount = 0
                                }
                            }
                        aiSettingsRow
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showLinkedInSheet) {
                LinkedInImportSheet(
                    onComplete: { count in
                        let previous = UserDefaults.standard.integer(forKey: linkedInCountKey)
                        let total = previous + count
                        UserDefaults.standard.set(total, forKey: linkedInCountKey)
                        importedCount = total
                    }
                )
            }
            .sheet(isPresented: $showToneSettingsSheet) {
                ToneSettingsSheet()
            }
            .sheet(isPresented: $showGeminiKeySheet) {
                GeminiKeySheet()
            }
            .sheet(isPresented: $showCalendarSuggestions) {
                CalendarSuggestionsSheet()
                    .environment(googleState)
            }
            .alert("Google Error", isPresented: Binding(
                get: { googleErrorMessage != nil },
                set: { if !$0 { googleErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { googleErrorMessage = nil }
            } message: {
                Text(googleErrorMessage ?? "")
            }
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task { try? await SupabaseService.shared.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to access Ping.")
            }
        }
        .task(id: authViewModel.userId) {
            importedCount = UserDefaults.standard.integer(forKey: linkedInCountKey)
        }
        .enableInjection()
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.pingTextMuted)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Signed in")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.pingTextPrimary)
                    if let email = SupabaseService.shared.currentUserEmail {
                        Text(email)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pingTextMuted)
                    }
                }

                Spacer()

                Button("Sign Out") {
                    showSignOutConfirm = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.pingDestructive)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
    }

    // MARK: - Google Section

    @ViewBuilder
    private var googleSection: some View {
        VStack(spacing: 0) {
            if googleState.isConnected {
                connectedGoogleRows
            } else {
                connectGoogleRow
            }
        }
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
    }

    private var connectGoogleRow: some View {
        Button {
            Task { await signIn() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.pingAccent)
                    .frame(width: 36)

                Text("Connect Google")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.pingTextPrimary)

                Spacer()

                if isSigningIn {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.pingTextSubtle)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .disabled(isSigningIn)
    }

    @ViewBuilder
    private var connectedGoogleRows: some View {
        // Header
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.pingSuccess)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text("Google Connected")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.pingTextPrimary)
                Text(googleState.userEmail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pingTextMuted)
            }

            Spacer()

            Button("Disconnect") {
                GoogleAuthService.signOut()
                googleState.googleUser = nil
                googleState.calendarSuggestions = []
                googleState.gmailSuggestions = []
                contactsImportCount = nil
            }
            .font(.system(size: 13))
            .foregroundStyle(Color.pingDestructive)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)

        Divider().padding(.leading, 70)

        googleSubRow(icon: "person.2.fill", iconColor: Color.pingAccent2, title: "Contacts",
                     subtitle: contactsImportCount.map { "\($0) contacts imported" },
                     isLoading: isImportingContacts, actionLabel: contactsImportCount == nil ? "Import" : "Re-import") {
            Task { await importContacts() }
        }

        Divider().padding(.leading, 70)

        googleSubRow(icon: "calendar", iconColor: Color.pingAccent, title: "Calendar",
                     subtitle: googleState.calendarSuggestions.isEmpty ? nil : "\(googleState.calendarSuggestions.count) suggestions",
                     isLoading: isScanningCalendar, actionLabel: "Scan") {
            Task { await scanCalendar() }
        }

        Divider().padding(.leading, 70)

        googleSubRow(icon: "envelope.fill", iconColor: Color.pingAccent, title: "Gmail",
                     subtitle: googleState.gmailSuggestions.isEmpty ? nil : "\(googleState.gmailSuggestions.count) suggestions",
                     isLoading: isScanningGmail, actionLabel: "Scan") {
            Task { await scanGmail() }
        }

        // Gmail suggestions
        if !googleState.gmailSuggestions.isEmpty {
            Divider().padding(.leading, 16)
            gmailSuggestionsList
        }
    }

    private func googleSubRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String?,
        isLoading: Bool,
        actionLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(iconColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.pingTextPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pingTextMuted)
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
            } else {
                Button(actionLabel, action: action)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.pingAccent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var gmailSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Frequently emailed — not in Ping")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.pingTextMuted)
                .tracking(0.5)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ForEach(googleState.gmailSuggestions) { suggestion in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.name)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.pingTextPrimary)
                        Text(suggestion.email)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pingTextMuted)
                    }
                    Spacer()
                    Button("Add to Ping") {
                        let s = suggestion
                        googleState.gmailSuggestions.removeAll { $0.id == s.id }
                        Task {
                            guard let userId = SupabaseService.shared.currentUserId else {
                                googleErrorMessage = "Please sign in again to continue."
                                return
                            }
                            let draft = ContactDraft(name: s.name, howMet: "Gmail", email: s.email)
                            let payload = ContactInsertPayload(draft: draft, userId: userId)
                            _ = try? await SupabaseService.shared.createContact(payload: payload)
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.pingAccent)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                if suggestion.id != googleState.gmailSuggestions.last?.id {
                    Divider().padding(.leading, 20)
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Google Actions

    private func signIn() async {
        guard let rootVC = rootViewController() else { return }
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            googleState.googleUser = try await GoogleAuthService.signIn(presenting: rootVC)
        } catch {
            googleErrorMessage = userFacingMessage(for: error)
        }
    }

    private func importContacts() async {
        guard let user = googleState.googleUser else { return }
        isImportingContacts = true
        defer { isImportingContacts = false }
        do {
            let token = try await GoogleAuthService.getAccessToken(user: user)
            let drafts = try await GoogleContactsService.fetchContacts(accessToken: token)
            let service = SupabaseService.shared
            guard let userId = service.currentUserId else {
                googleErrorMessage = "Please sign in again to continue."
                return
            }
            let existing = (try? await service.fetchContacts(userId: userId)) ?? []
            let (toImport, _) = LinkedInImportService.deduplicateAgainstExisting(drafts: drafts, existing: existing)
            var saved: [Contact] = []
            for draft in toImport {
                if let contact = try? await service.createContact(payload: ContactInsertPayload(draft: draft, userId: userId)) {
                    saved.append(contact)
                }
            }
            contactsImportCount = saved.count
            // Notify NetworkTabView to reload once all contacts are saved.
            if !saved.isEmpty {
                NotificationCenter.default.post(name: .contactsDidImport, object: nil)
            }
            Task.detached(priority: .background) {
                for contact in saved {
                    let text = "\(contact.name), \(contact.title ?? "") at \(contact.company ?? ""). Met at \(contact.howMet)."
                    if let embedding = try? await GeminiService.embed(text, taskType: .retrievalDocument) {
                        try? await service.updateContactEmbedding(id: contact.id, embeddingString: embedding.pgVectorLiteral)
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        } catch {
            googleErrorMessage = "Contacts import failed: \(error.localizedDescription)"
        }
    }

    private func scanCalendar() async {
        guard let user = googleState.googleUser else { return }
        isScanningCalendar = true
        defer { isScanningCalendar = false }
        do {
            let token = try await GoogleAuthService.getAccessToken(user: user)
            googleState.calendarSuggestions = try await GoogleCalendarService.fetchMeetingSuggestions(
                accessToken: token,
                userEmail: googleState.userEmail
            )
            if !googleState.calendarSuggestions.isEmpty {
                showCalendarSuggestions = true
            }
        } catch {
            googleErrorMessage = "Calendar scan failed: \(error.localizedDescription)"
        }
    }

    private func scanGmail() async {
        guard let user = googleState.googleUser else { return }
        isScanningGmail = true
        defer { isScanningGmail = false }
        do {
            let token = try await GoogleAuthService.getAccessToken(user: user)
            googleState.gmailSuggestions = try await GmailService.fetchContactSuggestions(accessToken: token)
        } catch {
            googleErrorMessage = "Gmail scan failed: \(error.localizedDescription)"
        }
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    // MARK: - LinkedIn Row

    private var linkedInRow: some View {
        Button {
            showLinkedInSheet = true
        } label: {
            HStack(spacing: 14) {
                // LinkedIn logo badge
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "0A66C2"))
                        .frame(width: 36, height: 36)
                    Text("in")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("LinkedIn")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.pingTextPrimary)

                    if importedCount > 0 {
                        Label("\(importedCount) contacts imported", systemImage: "checkmark")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pingSuccess)
                        Text("Share Sheet: enabled")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pingTextMuted)
                    } else {
                        Text("Import your connections")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pingTextMuted)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.pingTextSubtle)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.pingSurface)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var aiSettingsRow: some View {
        VStack(spacing: 0) {
            // Row 1: Gemini API Key
            Button {
                showGeminiKeySheet = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.pingAccent)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Gemini API Key")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.pingTextPrimary)
                        if KeychainHelper.get("GEMINI_API_KEY") != nil {
                            Text("Configured ✓")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.pingSuccess)
                        } else {
                            Text("Not set — AI features disabled")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.pingDestructive)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.pingTextSubtle)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 70)

            // Row 2: Writing Tone
            Button {
                showToneSettingsSheet = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.pingAccent)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Writing Tone")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.pingTextPrimary)
                        Text("Update how AI drafts should sound")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pingTextMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.pingTextSubtle)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Row 3: Embedding Backfill (developer tool — tap AI header 5 times to reveal)
            if showDeveloperTools {
            Divider().padding(.leading, 70)

            HStack(spacing: 14) {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.pingAccent)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Embedding Backfill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.pingTextPrimary)
                    Text(backfillResult ?? "Re-index contacts for semantic search")
                        .font(.system(size: 13))
                        .foregroundStyle(backfillResult != nil ? Color.pingSuccess : Color.pingTextMuted)
                }

                Spacer()

                if isBackfillingEmbeddings {
                    ProgressView()
                        .tint(Color.pingAccent)
                } else {
                    Button("Run") {
                        Task { await backfillEmbeddings() }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.pingAccent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            } // end showDeveloperTools
        }
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
    }

    private func backfillEmbeddings() async {
        guard !isBackfillingEmbeddings else { return }
        guard KeychainHelper.get("GEMINI_API_KEY") != nil else {
            backfillResult = "No API key configured"
            return
        }
        guard let userId = SupabaseService.shared.currentUserId else {
            backfillResult = "Please sign in again to continue."
            return
        }
        isBackfillingEmbeddings = true
        backfillResult = nil
        defer { isBackfillingEmbeddings = false }

        do {
            let ids = try await SupabaseService.shared.fetchContactIdsWithoutEmbedding(userId: userId)
            guard !ids.isEmpty else {
                backfillResult = "All contacts already indexed"
                return
            }
            let allContacts = try await SupabaseService.shared.fetchContacts(userId: userId)
            let toEmbed = allContacts.filter { ids.contains($0.id) }
            var count = 0
            for contact in toEmbed {
                let text = "\(contact.name), \(contact.title ?? "") at \(contact.company ?? ""). Met at \(contact.howMet). Notes: \(contact.notes ?? ""). Tags: \(contact.tags.joined(separator: ", "))"
                if let embedding = try? await GeminiService.embed(text, taskType: .retrievalDocument) {
                    try? await SupabaseService.shared.updateContactEmbedding(id: contact.id, embeddingString: embedding.pgVectorLiteral)
                    count += 1
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            backfillResult = "\(count) contact\(count == 1 ? "" : "s") indexed"
        } catch {
            backfillResult = "Failed: \(error.localizedDescription)"
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.pingTextMuted)
            .tracking(0.8)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }
}

private struct ToneSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var toneSample = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("How should drafts sound?")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.pingTextPrimary)

                    Text("Paste a few sentences in your voice. Ping uses this to personalize draft style.")
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextSecondary)

                    TextEditor(text: $toneSample)
                        .font(.body)
                        .foregroundStyle(Color.pingTextPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .padding(12)
                        .background(Color.pingSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    PingButton(title: isSaving ? "Saving…" : "Save Tone Sample") {
                        Task { await save() }
                    }
                    .disabled(isSaving || toneSample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(20)

                if isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("Writing Tone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.pingAccent)
                }
            }
            .task {
                await load()
            }
            .alert("Tone Settings Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let userId = await SupabaseService.shared.currentUserId else { return }
        do {
            let samples = try await SupabaseService.shared.fetchToneSamples(userId: userId)
            toneSample = samples.first ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        let trimmed = toneSample.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let userId = await SupabaseService.shared.currentUserId else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await SupabaseService.shared.replaceToneSamples([trimmed], userId: userId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Gemini Key Sheet

private struct GeminiKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    private var hasExistingKey: Bool { KeychainHelper.get("GEMINI_API_KEY") != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Gemini powers semantic search and message drafts. Get a free key at ai.google.dev.")
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextSecondary)

                    SecureField("Paste your API key here", text: $apiKey)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(Color.pingTextPrimary)
                        .padding(14)
                        .background(Color.pingSurface2)
                        .cornerRadius(14)

                    PingButton(title: "Save Key") {
                        save()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if hasExistingKey {
                        Button("Remove Key") {
                            KeychainHelper.delete("GEMINI_API_KEY")
                            dismiss()
                        }
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pingDestructive)
                        .frame(maxWidth: .infinity)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Gemini API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.pingAccent)
                }
            }
            .task {
                apiKey = KeychainHelper.get("GEMINI_API_KEY") ?? ""
            }
        }
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainHelper.set("GEMINI_API_KEY", value: trimmed)
        dismiss()
    }
}

// MARK: - Calendar Suggestions Sheet

struct CalendarSuggestionsSheet: View {
    @ObserveInjection var inject
    @Environment(GoogleIntegrationState.self) private var googleState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()

                if googleState.calendarSuggestions.isEmpty {
                    Text("No new people found in your recent meetings.")
                        .foregroundStyle(Color.pingTextMuted)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List {
                        ForEach(googleState.calendarSuggestions) { suggestion in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(suggestion.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.pingTextPrimary)
                                    Text(suggestion.eventTitle)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.pingTextMuted)
                                    Text(suggestion.eventDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.pingTextSubtle)
                                }

                                Spacer()

                                Button("Add") {
                                    let s = suggestion
                                    googleState.calendarSuggestions.removeAll { $0.id == s.id }
                                    Task {
                                        guard let userId = SupabaseService.shared.currentUserId else { return }
                                        let draft = ContactDraft(name: s.name, howMet: "Met at \(s.eventTitle)", email: s.email)
                                        let payload = ContactInsertPayload(draft: draft, userId: userId)
                                        if let contact = try? await SupabaseService.shared.createContact(payload: payload) {
                                            let text = "\(contact.name) at \(contact.company ?? ""). Met at \(s.eventTitle)."
                                            if let embedding = try? await GeminiService.embed(text, taskType: .retrievalDocument) {
                                                try? await SupabaseService.shared.updateContactEmbedding(id: contact.id, embeddingString: embedding.pgVectorLiteral)
                                            }
                                        }
                                    }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.pingAccent)
                                .clipShape(Capsule())
                            }
                            .listRowBackground(Color.pingSurface)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Recent Meetings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.pingAccent)
                }
            }
        }
        .enableInjection()
    }
}

// MARK: - LinkedIn Import Sheet

private struct LinkedInImportSheet: View {
    let onComplete: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phase: ImportPhase = .idle
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()
                content
            }
            .navigationTitle("Import LinkedIn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .importing = phase {
                        EmptyView()
                    } else {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Color.pingAccent)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFilePicked(result)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            instructionsView
        case .preview(let drafts, let skipped):
            previewView(drafts: drafts, alreadySkipped: skipped)
        case .importing(let current, let total):
            progressView(current: current, total: total)
        case .done(let imported, let skipped):
            doneView(imported: imported, skipped: skipped)
        case .failed(let message):
            errorView(message: message)
        }
    }

    // MARK: - Instructions

    private var instructionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to export your LinkedIn connections")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.pingTextPrimary)

                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.pingSurface)
                                .frame(width: 22, height: 22)
                                .background(Color.pingAccent)
                                .clipShape(Circle())
                                .padding(.top, 1)
                            Text(step)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.pingTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(20)
                .background(Color.pingSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

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
            }
            .padding(20)
        }
    }

    private let steps: [String] = [
        "Open LinkedIn and tap your profile photo",
        "Go to Settings & Privacy",
        "Tap Data Privacy → Get a copy of your data",
        "Select Connections and request the archive",
        "Download the ZIP and open Connections.csv",
        "Come back here and tap Choose CSV file"
    ]

    // MARK: - Preview

    private func previewView(drafts: [ContactDraft], alreadySkipped: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pingAccent)

            VStack(spacing: 8) {
                Text("Found \(drafts.count) connections")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.pingTextPrimary)

                if alreadySkipped > 0 {
                    Text("\(alreadySkipped) already in Ping — will be skipped")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pingTextMuted)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await runImport(drafts: drafts, skippedSoFar: alreadySkipped) }
                } label: {
                    Text("Import All")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.pingAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    phase = .idle
                } label: {
                    Text("Choose a different file")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pingTextSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Progress

    private func progressView(current: Int, total: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.pingAccent)
            Text("Importing \(current)/\(total)...")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.pingTextSecondary)
            Spacer()
        }
    }

    // MARK: - Done

    private func doneView(imported: Int, skipped: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.pingSuccess)

            VStack(spacing: 8) {
                Text("\(imported) contacts imported")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.pingTextPrimary)

                if skipped > 0 {
                    Text("\(skipped) duplicate\(skipped == 1 ? "" : "s") skipped")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pingTextMuted)
                }
            }

            Spacer()

            Button {
                onComplete(imported)
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
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pingDestructive)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Color.pingTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                phase = .idle
            } label: {
                Text("Try Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.pingAccent)
            }
            Spacer()
        }
    }

    // MARK: - Logic

    private func handleFilePicked(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            phase = .failed("Could not open file: \(error.localizedDescription)")
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let drafts = try LinkedInImportService.parseCSV(url)
                guard !drafts.isEmpty else {
                    phase = .failed("No valid contacts found in this file. Make sure you're using the LinkedIn Connections CSV.")
                    return
                }
                Task {
                    await deduplicateAndPreview(drafts: drafts)
                }
            } catch {
                phase = .failed("Could not parse CSV: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func deduplicateAndPreview(drafts: [ContactDraft]) async {
        let service = SupabaseService.shared
        guard let userId = await service.currentUserId else {
            phase = .failed("You must be signed in to import contacts.")
            return
        }
        let existing = (try? await service.fetchContacts(userId: userId)) ?? []
        let (toImport, skipped) = LinkedInImportService.deduplicateAgainstExisting(
            drafts: drafts,
            existing: existing
        )
        phase = .preview(drafts: toImport, skipped: skipped)
    }

    @MainActor
    private func runImport(drafts: [ContactDraft], skippedSoFar: Int) async {
        let service = SupabaseService.shared
        guard let userId = await service.currentUserId else {
            phase = .failed("You must be signed in to import contacts.")
            return
        }

        let total = drafts.count
        phase = .importing(current: 0, total: total)

        var successfullyImported: [Contact] = []

        // Batch insert in groups of 20 to respect Supabase free-tier rate limits
        let batches = stride(from: 0, to: drafts.count, by: 20).map {
            Array(drafts[$0 ..< min($0 + 20, drafts.count)])
        }

        for batch in batches {
            for draft in batch {
                let payload = ContactInsertPayload(draft: draft, userId: userId)
                if let created = try? await service.createContact(payload: payload) {
                    successfullyImported.append(created)
                }
                phase = .importing(current: successfullyImported.count, total: total)
            }
        }

        phase = .done(imported: successfullyImported.count, skipped: skippedSoFar + (total - successfullyImported.count))

        // Background: generate embeddings throttled at 1/second
        Task.detached(priority: .background) {
            for contact in successfullyImported {
                let text = "\(contact.name), \(contact.title ?? "") at \(contact.company ?? ""). Met at \(contact.howMet)."
                if let embedding = try? await GeminiService.embed(text, taskType: .retrievalDocument) {
                    try? await service.updateContactEmbedding(id: contact.id, embeddingString: embedding.pgVectorLiteral)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}

#Preview {
    ProfileTabView(authViewModel: AuthViewModel())
        .environment(GoogleIntegrationState.shared)
}
