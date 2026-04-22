import SwiftUI
import Inject
import Supabase
import Speech
import AVFoundation

struct ContactDetailView: View {
    @ObserveInjection var inject
    let contact: Contact
    var nudge: Nudge? = nil
    /// Called after the user saves an edit, so parent views can refresh their list.
    var onContactUpdated: ((Contact) -> Void)? = nil

    @State private var contactViewModel = ContactViewModel()
    @State private var showMessageDraft = false
    @State private var showLogSheet = false
    @State private var logSheetIsNote = false
    @State private var showEditContact = false
    @State private var pingViewModel = PingViewModel()
    @State private var resolvedNudge: Nudge? = nil
    @State private var isResolvingNudge = false

    private func resolveAndOpenDraft() async {
        if let existing = nudge {
            resolvedNudge = existing
        } else {
            isResolvingNudge = true
            defer { isResolvingNudge = false }
            guard let userId = SupabaseService.shared.currentUserId else { return }
            resolvedNudge = try? await SupabaseService.shared.createNudge(
                contactId: contact.id,
                userId: userId,
                reason: "General check-in"
            )
        }
        if resolvedNudge != nil { showMessageDraft = true }
    }

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
                Button("Edit") { showEditContact = true }
                    .foregroundStyle(Color.pingAccent)
            }
        }
        .sheet(isPresented: $showMessageDraft) {
            if let nudge = resolvedNudge {
                MessageDraftView(nudge: nudge, contact: contact, pingViewModel: pingViewModel)
            }
        }
        .sheet(isPresented: $showLogSheet) {
            LogInteractionSheet(isNote: logSheetIsNote, contactViewModel: contactViewModel)
        }
        .sheet(isPresented: $showEditContact) {
            EditContactSheet(contact: contactViewModel.contact ?? contact) { updated in
                contactViewModel.contact = updated
                onContactUpdated?(updated)
            }
        }
        .onAppear {
            Task { await contactViewModel.load(contactId: contact.id) }
        }
        .enableInjection()
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ContactAvatarView(name: contact.name, size: 72)
                WarmthDot(score: contactViewModel.contact?.warmthScore ?? contact.warmthScore, size: 12, showLegendOnTap: true)
                    .offset(x: 4, y: -4)
            }

            Text(contact.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.pingTextPrimary)

            let displayContact = contactViewModel.contact ?? contact
            if let company = displayContact.company, let title = displayContact.title {
                Text("\(company) · \(title)")
                    .font(.subheadline)
                    .foregroundStyle(Color.pingTextSecondary)
            } else if let company = displayContact.company {
                Text(company)
                    .font(.subheadline)
                    .foregroundStyle(Color.pingTextSecondary)
            }

            Text(warmthLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(warmthColor)

            HStack(spacing: 20) {
                if let email = displayContact.email {
                    Link(destination: URL(string: "mailto:\(email)")!) {
                        Image(systemName: "envelope.fill")
                            .font(.title3)
                            .foregroundStyle(Color.pingTextMuted)
                    }
                }
                if let urlStr = displayContact.linkedinUrl, let url = URL(string: urlStr) {
                    Link(destination: url) {
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

            if contactViewModel.isLoading {
                VStack(alignment: .leading, spacing: 8) {
                    ShimmerBox(height: 14, cornerRadius: 6)
                    ShimmerBox(width: 220, height: 14, cornerRadius: 6)
                    ShimmerBox(width: 160, height: 14, cornerRadius: 6)
                }
                Text("Generating draft...")
                    .font(.caption)
                    .foregroundStyle(Color.pingTextMuted)
            } else if !contactViewModel.messageDraft.isEmpty {
                Text("\"\(contactViewModel.messageDraft)\"")
                    .font(.body)
                    .italic()
                    .foregroundStyle(Color.pingTextPrimary)
            } else {
                Text("Set up Gemini in Profile → Settings to enable AI drafts.")
                    .font(.subheadline)
                    .foregroundStyle(Color.pingTextMuted)
            }

            PingButton(title: isResolvingNudge ? "" : "Edit & Send →", action: {
                Task { await resolveAndOpenDraft() }
            }, style: .primary)
            .disabled(isResolvingNudge)
            .overlay {
                if isResolvingNudge {
                    ProgressView().tint(.white)
                }
            }

            Button {
                Task {
                    await contactViewModel.generateDraft(
                        contact: contactViewModel.contact ?? contact,
                        nudgeReason: nudge?.reason ?? "General check-in",
                        forceRefresh: true
                    )
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
        let displayContact = contactViewModel.contact ?? contact
        return VStack(alignment: .leading, spacing: 0) {
            Text("Context")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.pingTextMuted)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                contextRow(icon: "mappin.circle.fill", label: "How we met", value: displayContact.howMet)
                Divider().padding(.leading, 44)
                if let metAt = displayContact.metAt {
                    contextRow(icon: "calendar", label: "Date met", value: metAt.shortFormatted)
                    Divider().padding(.leading, 44)
                }
                if let notes = displayContact.notes {
                    contextRow(icon: "note.text", label: "Notes", value: notes)
                    Divider().padding(.leading, 44)
                }
                if !displayContact.tags.isEmpty {
                    contextRow(icon: "tag.fill", label: "Tags", value: displayContact.tags.map { "#\($0)" }.joined(separator: "  "))
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
                if contactViewModel.interactions.isEmpty {
                    Text("No interactions yet.")
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(20)
                } else {
                    let sorted = contactViewModel.interactions.sorted { $0.occurredAt > $1.occurredAt }
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
                        logSheetIsNote = true
                        showLogSheet = true
                    } label: {
                        Label("Add Note", systemImage: "note.text.badge.plus")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .foregroundStyle(Color.pingAccent)

                    Divider().frame(height: 20)

                    Button {
                        logSheetIsNote = false
                        showLogSheet = true
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

    private var warmthCategory: WarmthCategory {
        WarmthCategory(score: contactViewModel.contact?.warmthScore ?? contact.warmthScore)
    }

    private var warmthLabel: String { warmthCategory.label }
    private var warmthColor: Color  { warmthCategory.color }
}

// MARK: - Log Interaction Sheet

private struct LogInteractionSheet: View {
    let isNote: Bool
    let contactViewModel: ContactViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var noteText = ""
    @State private var selectedType: InteractionType = .message
    @State private var notesText = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                if isNote {
                    Section {
                        VoiceInputField(
                            label: "Note",
                            placeholder: "Add a note…",
                            text: $noteText,
                            style: .multiline,
                            minHeight: 100,
                            isRequired: true
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("Interaction Type") {
                        Picker("Type", selection: $selectedType) {
                            Text("Message").tag(InteractionType.message)
                            Text("Call").tag(InteractionType.call)
                            Text("Met in person").tag(InteractionType.met)
                        }
                        .pickerStyle(.segmented)
                    }
                    Section {
                        VoiceInputField(
                            label: "Notes (optional)",
                            placeholder: "Any details…",
                            text: $notesText,
                            style: .multiline,
                            minHeight: 80
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle(isNote ? "Add Note" : "Log Interaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        let type: InteractionType = isNote ? .note : selectedType
                        let notes: String? = isNote
                            ? (noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : noteText)
                            : (notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notesText)
                        Task {
                            await contactViewModel.logInteraction(type: type, notes: notes)
                            dismiss()
                        }
                    }
                    .disabled(isSaving || (isNote && noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
        }
    }
}

// MARK: - Edit Contact Sheet

struct EditContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    let contact: Contact
    let onSave: (Contact) -> Void

    @State private var name: String
    @State private var company: String
    @State private var title: String
    @State private var howMet: String
    @State private var notes: String
    @State private var linkedinUrl: String
    @State private var email: String
    @State private var phone: String
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    init(contact: Contact, onSave: @escaping (Contact) -> Void) {
        self.contact = contact
        self.onSave = onSave
        _name        = State(initialValue: contact.name)
        _company     = State(initialValue: contact.company ?? "")
        _title       = State(initialValue: contact.title ?? "")
        _howMet      = State(initialValue: contact.howMet)
        _notes       = State(initialValue: contact.notes ?? "")
        _linkedinUrl = State(initialValue: contact.linkedinUrl ?? "")
        _email       = State(initialValue: contact.email ?? "")
        _phone       = State(initialValue: contact.phone ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !howMet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    LabeledContent("Name") {
                        TextField("Full name", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Company") {
                        TextField("Company", text: $company)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Title") {
                        TextField("Job title", text: $title)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    VoiceInputField(
                        label: "How You Met",
                        placeholder: "e.g. Conference, intro from Sarah…",
                        text: $howMet,
                        style: .multiline,
                        minHeight: 60,
                        isRequired: true
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section {
                    VoiceInputField(
                        label: "Notes",
                        placeholder: "Any extra context…",
                        text: $notes,
                        style: .multiline,
                        minHeight: 80
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section("Contact Info") {
                    LabeledContent("Email") {
                        TextField("Email", text: $email)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    LabeledContent("Phone") {
                        TextField("Phone", text: $phone)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.phonePad)
                    }
                    LabeledContent("LinkedIn") {
                        TextField("https://linkedin.com/in/…", text: $linkedinUrl)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveContact() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func saveContact() {
        isSaving = true
        errorMessage = nil
        Task {
            var fields: [String: AnyJSON] = [
                "name":    .string(name.trimmingCharacters(in: .whitespacesAndNewlines)),
                "how_met": .string(howMet.trimmingCharacters(in: .whitespacesAndNewlines))
            ]
            let trimmedCompany     = company.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTitle       = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNotes       = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLinkedin    = linkedinUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedEmail       = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPhone       = phone.trimmingCharacters(in: .whitespacesAndNewlines)

            fields["company"]      = trimmedCompany.isEmpty    ? .null : .string(trimmedCompany)
            fields["title"]        = trimmedTitle.isEmpty       ? .null : .string(trimmedTitle)
            fields["notes"]        = trimmedNotes.isEmpty       ? .null : .string(trimmedNotes)
            fields["linkedin_url"] = trimmedLinkedin.isEmpty    ? .null : .string(trimmedLinkedin)
            fields["email"]        = trimmedEmail.isEmpty       ? .null : .string(trimmedEmail)
            fields["phone"]        = trimmedPhone.isEmpty       ? .null : .string(trimmedPhone)

            do {
                try await SupabaseService.shared.updateContact(id: contact.id, fields: fields)
                var updated = contact
                updated.name        = name.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.howMet      = howMet.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.company     = trimmedCompany.isEmpty    ? nil : trimmedCompany
                updated.title       = trimmedTitle.isEmpty       ? nil : trimmedTitle
                updated.notes       = trimmedNotes.isEmpty       ? nil : trimmedNotes
                updated.linkedinUrl = trimmedLinkedin.isEmpty    ? nil : trimmedLinkedin
                updated.email       = trimmedEmail.isEmpty       ? nil : trimmedEmail
                updated.phone       = trimmedPhone.isEmpty       ? nil : trimmedPhone
                onSave(updated)
                dismiss()
                // Re-generate the semantic embedding in the background so search
                // reflects the updated name/company/title/notes/howMet.
                let snapshot = updated
                Task.detached(priority: .background) {
                    let text = "\(snapshot.name), \(snapshot.title ?? "") at \(snapshot.company ?? ""). Met at \(snapshot.howMet). Notes: \(snapshot.notes ?? "")."
                    if let embedding = try? await GeminiService.embed(text, taskType: .retrievalDocument) {
                        try? await SupabaseService.shared.updateContactEmbedding(
                            id: snapshot.id,
                            embeddingString: embedding.pgVectorLiteral
                        )
                    }
                }
            } catch {
                isSaving = false
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    NavigationStack {
        ContactDetailView(contact: .preview)
    }
}
