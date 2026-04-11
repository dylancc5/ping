import SwiftUI
import Inject

struct NetworkTabView: View {
    @ObserveInjection var inject
    @Environment(GoogleIntegrationState.self) private var googleState

    @State private var searchText = ""
    @State private var isGridView = false
    @State private var showQuickCapture = false
    @State private var showCalendarSuggestions = false

    // In Phase 2 this will come from a ViewModel / environment
    private let contacts: [Contact] = Contact.previewSamples

    private var filtered: [Contact] {
        let sorted = contacts.sorted {
            ($0.lastContactedAt ?? .distantPast) > ($1.lastContactedAt ?? .distantPast)
        }
        guard !searchText.isEmpty else { return sorted }
        let q = searchText.lowercased()
        return sorted.filter {
            $0.name.lowercased().contains(q) ||
            ($0.company?.lowercased().contains(q) ?? false) ||
            ($0.title?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.pingBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if !googleState.calendarSuggestions.isEmpty {
                        calendarBanner
                    }

                    if filtered.isEmpty {
                        emptyState
                    } else if isGridView {
                        gridContent
                    } else {
                        listContent
                    }
                }

                fab
            }
            .navigationTitle("Network")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isGridView.toggle()
                    } label: {
                        Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                            .foregroundStyle(Color.pingTextPrimary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search by name or company...")
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureView()
            }
            .sheet(isPresented: $showCalendarSuggestions) {
                CalendarSuggestionsSheet()
                    .environment(googleState)
            }
        }
        .enableInjection()
    }

    // MARK: - Subviews

    private var calendarBanner: some View {
        Button {
            showCalendarSuggestions = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pingAccent)

                Text("You met \(googleState.calendarSuggestions.count) people recently — add them?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.pingTextPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pingTextSubtle)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.pingAccentLight)
        }
        .buttonStyle(.plain)
    }

    private var listContent: some View {
        List {
            ForEach(filtered) { contact in
                NavigationLink(destination: ContactDetailView(contact: contact)) {
                    ContactRowView(contact: contact)
                }
                .listRowBackground(Color.pingBackground)
                .listRowSeparatorTint(Color.pingSurface3)
            }
        }
        .listStyle(.plain)
        .refreshable { }
    }

    private var gridContent: some View {
        ScrollView {
            ContactCardGridView(contacts: filtered)
                .padding(.top, 8)
        }
        .refreshable { }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 44))
                .foregroundStyle(Color.pingTextMuted)
            Text("Your network starts here.")
                .font(.headline)
                .foregroundStyle(Color.pingTextPrimary)
            Text("Log your first contact.")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
            PingButton(title: "Add Contact", style: .primary) {
                showQuickCapture = true
            }
            .frame(maxWidth: 200)
        }
        .padding(.horizontal, 40)
    }

    private var fab: some View {
        Button {
            showQuickCapture = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.pingAccent)
                .clipShape(Circle())
                .pingCardShadow()
        }
        .padding(24)
    }
}

#Preview {
    NetworkTabView()
        .environment(GoogleIntegrationState.shared)
}
