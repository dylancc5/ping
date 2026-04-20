import SwiftUI

struct RecommendationFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: RecommendationViewModel
    let contacts: [Contact]

    var body: some View {
        NavigationStack {
            List {
                // MARK: Recommendation modes
                Section {
                    ForEach(RecommendationMode.allCases) { mode in
                        modeRow(mode)
                    }
                } header: {
                    Text("Recommendation Methods")
                } footer: {
                    Text("Toggle which methods are used to surface people in your network.")
                }

                // MARK: Position tiers (shown only when positionTarget is enabled)
                if viewModel.filter.enabledModes.contains(.positionTarget) {
                    Section {
                        ForEach(PositionTier.allCases.filter { $0 != .recruiter }) { tier in
                            tierRow(tier)
                        }
                    } header: {
                        Text("Target Seniority Levels")
                    } footer: {
                        Text("Contacts at these levels will surface in 'By Position' recommendations.")
                    }
                }
            }
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.saveFilter()
                        Task { await viewModel.compute(contacts: contacts) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.pingAccent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Mode toggle row

    private func modeRow(_ mode: RecommendationMode) -> some View {
        HStack(spacing: 14) {
            Image(systemName: mode.systemImage)
                .font(.system(size: 18))
                .foregroundStyle(Color.pingAccent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.displayName)
                    .font(.body)
                    .foregroundStyle(Color.pingTextPrimary)
                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(Color.pingTextSecondary)
            }

            Spacer()

            Toggle("", isOn: modeBinding(mode))
                .labelsHidden()
                .tint(Color.pingAccent)
        }
        .padding(.vertical, 4)
    }

    private func modeBinding(_ mode: RecommendationMode) -> Binding<Bool> {
        Binding(
            get: { viewModel.filter.enabledModes.contains(mode) },
            set: { enabled in
                if enabled {
                    viewModel.filter.enabledModes.insert(mode)
                } else {
                    viewModel.filter.enabledModes.remove(mode)
                }
            }
        )
    }

    // MARK: - Tier checkbox row

    private func tierRow(_ tier: PositionTier) -> some View {
        HStack(spacing: 14) {
            Image(systemName: tier.systemImage)
                .font(.system(size: 16))
                .foregroundStyle(Color.pingTextSecondary)
                .frame(width: 28)

            Text(tier.displayName)
                .font(.body)
                .foregroundStyle(Color.pingTextPrimary)

            Spacer()

            if viewModel.filter.targetTiers.contains(tier) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.pingAccent)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.filter.targetTiers.contains(tier) {
                viewModel.filter.targetTiers.remove(tier)
            } else {
                viewModel.filter.targetTiers.insert(tier)
            }
        }
        .padding(.vertical, 4)
    }
}
