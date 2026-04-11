import SwiftUI
import Inject

struct SemanticSearchView: View {
    @ObserveInjection var inject
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        Group {
            if viewModel.isSearching {
                shimmerRows
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
            ForEach(viewModel.searchResults) { result in
                SearchResultRowView(result: result)
                    .listRowBackground(Color.pingBackground)
                    .listRowSeparatorTint(Color.pingSurface3)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.pingTextMuted)
            Text("No results for "\(viewModel.query)"")
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
    let result: ContactSearchResult
    @State private var contact: Contact?

    private var subtitle: String {
        [result.company, result.title]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        NavigationLink(destination: destinationView) {
            HStack(spacing: 12) {
                ContactAvatarView(name: result.name, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.headline)
                        .foregroundStyle(Color.pingTextPrimary)
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
        .task {
            contact = try? await SupabaseService.shared.fetchContact(id: result.id)
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

#Preview {
    SemanticSearchView(viewModel: SearchViewModel())
}
