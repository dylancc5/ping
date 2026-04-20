import SwiftUI
import Inject

struct SemanticSearchView: View {
    @ObserveInjection var inject
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        Group {
            if viewModel.isSearching {
                shimmerRows
            } else if viewModel.error != nil {
                errorState
            } else if viewModel.searchResults.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .enableInjection()
    }

    // MARK: - Results list

    private var resultsList: some View {
        List {
            Section {
                ForEach(viewModel.searchResults) { ranked in
                    SearchResultRowView(ranked: ranked)
                        .listRowBackground(Color.pingBackground)
                        .listRowSeparatorTint(Color.pingSurface3)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                }
            } header: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("AI · \(viewModel.searchResults.count) ranked")
                        .font(.caption)
                }
                .foregroundStyle(Color.pingAccent)
                .textCase(nil)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Error state

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.pingDestructive)
            Text("Search unavailable")
                .font(.headline)
                .foregroundStyle(Color.pingTextPrimary)
            Text(viewModel.error.map { userFacingMessage(for: $0) } ?? "Something went wrong.")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.pingTextMuted)
            Text("No results for \"\(viewModel.query)\"")
                .font(.headline)
                .foregroundStyle(Color.pingTextPrimary)
            Text("Try adding them as a new contact.")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shimmer loading

    private var shimmerRows: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 12) {
                    ShimmerBox(width: 44, height: 44, cornerRadius: 22)
                    VStack(alignment: .leading, spacing: 6) {
                        ShimmerBox(width: 140, height: 14)
                        ShimmerBox(width: 100, height: 12)
                        ShimmerBox(width: 80, height: 11)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                Divider()
                    .padding(.leading, 76)
            }
            Spacer()
        }
    }
}

// MARK: - Row

private struct SearchResultRowView: View {
    let ranked: RankedSearchResult

    private var result: ContactSearchResult { ranked.result }

    private var subtitle: String {
        [result.company, result.title]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// Build a lightweight Contact stub from the search result so we can
    /// navigate immediately. ContactDetailView loads the full record on appear.
    private var contactStub: Contact {
        Contact(
            id: result.id,
            userId: UUID(), // placeholder; ContactDetailView fetches the real record
            name: result.name,
            company: result.company,
            title: result.title,
            howMet: result.howMet,
            warmthScore: result.warmthScore,
            lastContactedAt: result.lastContactedAt,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    var body: some View {
        NavigationLink(destination: ContactDetailView(contact: contactStub)) {
            HStack(spacing: 12) {
                ContactAvatarView(name: result.name, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(result.name)
                            .font(.headline)
                            .foregroundStyle(Color.pingTextPrimary)

                        if ranked.hasBioMatch {
                            Text("keyword match")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.pingAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.pingAccent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.pingTextSecondary)
                            .lineLimit(1)
                    }
                    Text("Met \(result.howMet)")
                        .font(.caption)
                        .foregroundStyle(Color.pingTextMuted)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    SemanticSearchView(viewModel: SearchViewModel())
}
