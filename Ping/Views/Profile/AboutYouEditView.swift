import SwiftUI

// Full-screen "About You" editor used both from ProfileTab and as tutorial step 3.
// Saves to Supabase via AuthViewModel; can be dismissed without saving (skippable).
struct AboutYouEditView: View {

    @ObservedObject var authViewModel: AuthViewModel
    var onSave: (() -> Void)? = nil
    var onSkip: (() -> Void)? = nil
    var isTutorialStep: Bool = false

    @Environment(\.dismiss) private var dismiss

    // Local editing state — mirrors UserProfile fields
    @State private var careerRole = ""
    @State private var careerCompany = ""
    @State private var careerIndustry = ""
    @State private var careerSeniority = ""
    @State private var interestsText = ""   // comma-separated
    @State private var city = ""
    @State private var hometown = ""
    @State private var school = ""
    @State private var aboutMe = ""

    @State private var isSaving = false

    private let seniorityOptions = ["Student / Intern", "Individual Contributor", "Manager", "Director", "VP", "C-Suite / Executive"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        if isTutorialStep {
                            tutorialHeader
                        }

                        careerSection
                        locationSection
                        interestsSection
                        aboutMeSection
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, isTutorialStep ? 0 : 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isTutorialStep ? "" : "About You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isTutorialStep {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Color.pingAccent)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await save() } }
                            .disabled(isSaving)
                            .foregroundStyle(Color.pingAccent)
                    }
                }
            }
        }
        .onAppear { seedFromViewModel() }
    }

    // MARK: - Tutorial Header

    private var tutorialHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tell us about yourself")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.pingTextPrimary)
            Text("This helps Ping surface contacts who are most relevant to you and your goals.")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Career Section

    private var careerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("CAREER")
            inputField(label: "Current Role", placeholder: "e.g. Product Manager", text: $careerRole)
            inputField(label: "Company", placeholder: "e.g. Google", text: $careerCompany)
            inputField(label: "Industry", placeholder: "e.g. AI / SaaS / Fintech", text: $careerIndustry)

            VStack(alignment: .leading, spacing: 6) {
                Text("Seniority")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pingTextSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(seniorityOptions, id: \.self) { option in
                            let selected = careerSeniority == option
                            Button {
                                careerSeniority = selected ? "" : option
                            } label: {
                                Text(option)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(selected ? Color.pingAccent : Color.pingSurface2)
                                    .foregroundStyle(selected ? .white : Color.pingTextPrimary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("LOCATION & BACKGROUND")
            inputField(label: "City", placeholder: "e.g. San Francisco", text: $city)
            inputField(label: "Hometown", placeholder: "e.g. Austin, TX", text: $hometown)
            inputField(label: "School / University", placeholder: "e.g. UC Berkeley", text: $school)
        }
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("INTERESTS")
            Text("Separate with commas. Ping uses these to find contacts you have things in common with.")
                .font(.caption)
                .foregroundStyle(Color.pingTextMuted)
            VoiceInputField(
                label: "Interests",
                placeholder: "e.g. Machine learning, Rock climbing, Startups",
                text: $interestsText,
                style: .singleLine
            )
        }
    }

    // MARK: - About Me Section

    private var aboutMeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("WHAT YOU'RE LOOKING FOR")
            Text("Who do you want to meet? What are you working on?")
                .font(.caption)
                .foregroundStyle(Color.pingTextMuted)
            VoiceInputField(
                label: "About Me",
                placeholder: "e.g. I'm building a startup in AI and looking to connect with other founders and investors…",
                text: $aboutMe,
                style: .multiline,
                minHeight: 100
            )
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if isTutorialStep {
            VStack(spacing: 12) {
                PingButton(title: isSaving ? "Saving…" : "Save & Continue") {
                    Task { await save() }
                }
                .disabled(isSaving)

                Button("Skip for now") {
                    onSkip?()
                }
                .font(.subheadline)
                .foregroundStyle(Color.pingTextMuted)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.pingTextMuted)
            .tracking(0.8)
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.pingTextSecondary)
            TextField(placeholder, text: text)
                .font(.body)
                .foregroundStyle(Color.pingTextPrimary)
                .padding(12)
                .background(Color.pingSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func seedFromViewModel() {
        let p = authViewModel.userProfile
        careerRole      = p.careerRole ?? ""
        careerCompany   = p.careerCompany ?? ""
        careerIndustry  = p.careerIndustry ?? ""
        careerSeniority = p.careerSeniority ?? ""
        interestsText   = p.interests.joined(separator: ", ")
        city            = p.city ?? ""
        hometown        = p.hometown ?? ""
        school          = p.school ?? ""
        aboutMe         = p.aboutMe ?? ""
    }

    private func buildProfile() -> UserProfile {
        let interests = interestsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return UserProfile(
            careerRole:      careerRole.isEmpty ? nil      : careerRole,
            careerCompany:   careerCompany.isEmpty ? nil   : careerCompany,
            careerIndustry:  careerIndustry.isEmpty ? nil  : careerIndustry,
            careerSeniority: careerSeniority.isEmpty ? nil : careerSeniority,
            interests:       interests,
            city:            city.isEmpty ? nil             : city,
            hometown:        hometown.isEmpty ? nil         : hometown,
            school:          school.isEmpty ? nil           : school,
            aboutMe:         aboutMe.isEmpty ? nil          : aboutMe
        )
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        await authViewModel.saveUserProfile(buildProfile())
        onSave?()
        if !isTutorialStep { dismiss() }
    }
}

#Preview {
    AboutYouEditView(authViewModel: AuthViewModel())
}
