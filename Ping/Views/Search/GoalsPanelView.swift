import SwiftUI
import Inject

struct GoalsPanelView: View {
    @ObserveInjection var inject
    @Bindable var viewModel: SearchViewModel
    @State private var showAddGoal = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoadingGoals {
                    shimmerCards
                } else if viewModel.goals.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.goals) { goal in
                        GoalCardView(
                            goal: goal,
                            matches: viewModel.goalMatches[goal.id] ?? [],
                            viewModel: viewModel
                        )
                    }
                }

                addGoalButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showAddGoal) {
            AddGoalSheet(viewModel: viewModel)
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
    let viewModel: SearchViewModel

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
                        .foregroundStyle(Color.pingTextMuted)
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

            // Matched contacts
            if matches.isEmpty {
                Text("Finding relevant contacts…")
                    .font(.caption)
                    .foregroundStyle(Color.pingTextMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(matches.prefix(3)) { match in
                        GoalMatchRowView(match: match)
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
    @State private var contact: Contact?

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

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.pingTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .task {
            contact = try? await SupabaseService.shared.fetchContact(id: match.id)
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        if let contact {
            ContactDetailView(contact: contact)
        } else {
            ProgressView()
        }
    }
}

// MARK: - Add Goal Sheet

private struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SearchViewModel

    @State private var text = ""
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

                Text("e.g. "Applying to Stripe for product roles" or "Fundraising for my seed round"")
                    .font(.caption)
                    .foregroundStyle(Color.pingTextMuted)

                Spacer()

                PingButton(title: "Save Goal", style: .primary) {
                    Task { await saveGoal() }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(24)
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.pingTextSecondary)
                }
            }
        }
        .onAppear { focused = true }
        .presentationDetents([.medium])
    }

    private func saveGoal() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await viewModel.addGoal(text: trimmed)

        // Grab the newly inserted goal (addGoal inserts at index 0)
        if let newGoal = viewModel.goals.first {
            Task {
                guard let embedding = try? await GeminiService.shared.embed(trimmed, taskType: .retrievalDocument) else { return }
                try? await SupabaseService.shared.updateGoalEmbedding(id: newGoal.id, embeddingString: embedding.pgVectorLiteral)
                await viewModel.loadGoals()
            }
        }

        dismiss()
    }
}

#Preview {
    GoalsPanelView(viewModel: SearchViewModel())
}
