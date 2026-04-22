import SwiftUI
import Inject

struct GoalsPanelView: View {
    @ObserveInjection var inject
    @Bindable var viewModel: SearchViewModel
    let contacts: [Contact]
    var userProfile: UserProfile = UserProfile()
    var onRefresh: (() async -> Void)? = nil
    @State private var showAddGoal = false
    @State private var recVM: RecommendationViewModel = RecommendationViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Recommendations section — shown above goals when contacts are available
                RecommendationsView(viewModel: recVM, contacts: contacts)

                if viewModel.isLoadingGoals {
                    shimmerCards
                } else if viewModel.goals.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.goals) { goal in
                        GoalCardView(
                            goal: goal,
                            matches: viewModel.goalMatches[goal.id] ?? [],
                            isLoadingMatches: viewModel.goalMatchLoading[goal.id] ?? false,
                            viewModel: viewModel,
                            matchedContacts: viewModel.matchedContacts
                        )
                    }
                }

                addGoalButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable {
            await onRefresh?()
            await recVM.compute(contacts: contacts, userProfile: userProfile)
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalSheet(viewModel: viewModel)
        }
        .task(id: contacts.count) {
            // Recompute recommendations whenever the contact list changes size
            await recVM.compute(contacts: contacts, userProfile: userProfile)
        }
        .enableInjection()
    }

    // MARK: - Add Goal button

    private var addGoalButton: some View {
        Button {
            showAddGoal = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                Text("Add a goal")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.pingAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 40))
                .foregroundStyle(Color.pingTextMuted)
            Text("No active goals yet.")
                .font(.headline)
                .foregroundStyle(Color.pingTextPrimary)
            Text("Add a goal to surface who's most relevant right now.")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }

    // MARK: - Shimmer placeholder cards

    private var shimmerCards: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    ShimmerBox(width: 200, height: 16)
                    Divider()
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: 10) {
                            ShimmerBox(width: 32, height: 32, cornerRadius: 16)
                            VStack(alignment: .leading, spacing: 4) {
                                ShimmerBox(width: 120, height: 13)
                                ShimmerBox(width: 80, height: 11)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(Color.pingSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .pingCardShadow()
            }
        }
    }
}

// MARK: - Goal Card

private struct GoalCardView: View {
    let goal: Goal
    let matches: [GoalContactMatch]
    let isLoadingMatches: Bool
    let viewModel: SearchViewModel
    let matchedContacts: [UUID: Contact]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                Text(goal.text)
                    .font(.headline)
                    .foregroundStyle(Color.pingTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    Task { await viewModel.deactivateGoal(goal) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.pingTextSecondary)
                        .padding(6)
                        .background(Color.pingSurface2)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .background(Color.pingSurface3)

            // Matched contacts — three distinct states
            if isLoadingMatches {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: 10) {
                            ShimmerBox(width: 32, height: 32, cornerRadius: 16)
                            VStack(alignment: .leading, spacing: 4) {
                                ShimmerBox(width: 110, height: 12)
                                ShimmerBox(width: 80, height: 10)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else if matches.isEmpty {
                Text("No matching contacts yet — add more contacts to build your network.")
                    .font(.caption)
                    .foregroundStyle(Color.pingTextSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(matches.prefix(3)) { match in
                        GoalMatchRowView(match: match, contact: matchedContacts[match.id])
                    }
                }
            }
        }
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .pingCardShadow()
    }
}

// MARK: - Goal Match Row

private struct GoalMatchRowView: View {
    let match: GoalContactMatch
    let contact: Contact?

    private var subtitle: String {
        [match.company, match.title]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        NavigationLink(destination: destinationView) {
            HStack(spacing: 10) {
                ContactAvatarView(name: match.name, size: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(match.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextPrimary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.pingTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text("\(Int(match.similarity * 100))% match")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.pingAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.pingAccentBadge)
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.pingTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        if let contact {
            ContactDetailView(contact: contact)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Add Goal Sheet

private struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SearchViewModel

    @State private var text = ""
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("What are you working toward?")
                    .font(.headline)
                    .foregroundStyle(Color.pingTextPrimary)

                TextField("I'm currently…", text: $text, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(Color.pingTextPrimary)
                    .padding(14)
                    .background(Color.pingSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .lineLimit(4...8)
                    .focused($focused)
                    .disabled(isSaving)

                Text("e.g. \"Applying to Stripe for product roles\" or \"Fundraising for my seed round\"")
                    .font(.caption)
                    .foregroundStyle(Color.pingTextMuted)

                if let err = saveError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                if isSaving {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Color.pingAccent)
                        Text("Saving goal…")
                            .font(.subheadline)
                            .foregroundStyle(Color.pingTextMuted)
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }

                PingButton(title: "Save Goal", action: {
                    Task { await saveGoal() }
                }, style: .primary)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
            .padding(24)
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.pingTextSecondary)
                        .disabled(isSaving)
                }
            }
        }
        .onAppear { focused = true }
        .presentationDetents([.medium])
    }

    private func saveGoal() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        saveError = nil

        // Use returned goal ID directly to avoid text-match ambiguity on duplicate goal text.
        if let newGoal = await viewModel.addGoal(text: trimmed) {
            if let embedding = try? await GeminiService.embed(trimmed, taskType: .retrievalDocument) {
                try? await SupabaseService.shared.updateGoalEmbedding(id: newGoal.id, embeddingString: embedding.pgVectorLiteral)
            }
            await viewModel.loadGoals()
        }

        isSaving = false
        dismiss()
    }
}

#Preview {
    GoalsPanelView(viewModel: SearchViewModel(), contacts: [])
}
