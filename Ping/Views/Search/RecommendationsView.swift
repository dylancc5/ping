import SwiftUI
import Inject

struct RecommendationsView: View {
    @ObserveInjection var inject
    @Bindable var viewModel: RecommendationViewModel
    let contacts: [Contact]
    @State private var showFilterSheet = false

    var body: some View {
        if viewModel.isComputing {
            shimmerCard
                .enableInjection()
        } else if !viewModel.results.isEmpty {
            card
                .sheet(isPresented: $showFilterSheet) {
                    RecommendationFilterSheet(viewModel: viewModel, contacts: contacts)
                }
                .enableInjection()
        }
        // Hidden when empty and not loading — no empty state needed here since GoalsPanelView
        // already handles the overall empty state.
    }

    // MARK: - Main card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("People to Reach Out To")
                    .font(.headline)
                    .foregroundStyle(Color.pingTextPrimary)
                Spacer()
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextSecondary)
                        .padding(6)
                        .background(Color.pingSurface2)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Mode chips
            if viewModel.filter.enabledModes.count > 1 {
                modeChips
                    .padding(.bottom, 10)
            }

            Divider()
                .background(Color.pingSurface3)

            // Results
            VStack(spacing: 0) {
                ForEach(viewModel.results.prefix(5)) { result in
                    RecommendationRowView(result: result)
                }
            }
        }
        .background(Color.pingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .pingCardShadow()
    }

    // MARK: - Mode filter chips

    private var modeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecommendationMode.allCases) { mode in
                    let isEnabled = viewModel.filter.enabledModes.contains(mode)
                    let hasResults = viewModel.results.contains { $0.mode == mode }
                    if isEnabled && hasResults {
                        modeChip(for: mode)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func modeChip(for mode: RecommendationMode) -> some View {
        HStack(spacing: 4) {
            Image(systemName: mode.systemImage)
                .font(.system(size: 11, weight: .medium))
            Text(mode.displayName)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(Color.pingAccent)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.pingAccentBadge)
        .clipShape(Capsule())
    }

    // MARK: - Shimmer placeholder

    private var shimmerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShimmerBox(width: 180, height: 16)
            Divider()
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 10) {
                    ShimmerBox(width: 36, height: 36, cornerRadius: 18)
                    VStack(alignment: .leading, spacing: 4) {
                        ShimmerBox(width: 120, height: 13)
                        ShimmerBox(width: 90, height: 11)
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

// MARK: - Recommendation Row

private struct RecommendationRowView: View {
    let result: RecommendationResult

    var body: some View {
        NavigationLink(destination: ContactDetailView(contact: result.contact)) {
            HStack(spacing: 10) {
                ContactAvatarView(name: result.contact.name, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.contact.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextPrimary)
                    Text(result.label)
                        .font(.caption)
                        .foregroundStyle(Color.pingTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                WarmthDot(score: result.contact.warmthScore, size: 8)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.pingTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
