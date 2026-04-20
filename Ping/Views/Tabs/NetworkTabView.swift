import SwiftUI
import Inject

struct NetworkTabView: View {
    @ObserveInjection var inject
    @Environment(GoogleIntegrationState.self) private var googleState

    @AppStorage("network.isGridView") private var isGridView = false
    @State private var showQuickCapture = false
    @State private var showCalendarSuggestions = false

    @State private var viewModel = NetworkViewModel()
    @State private var hasLoadedOnce = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.pingBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if !googleState.calendarSuggestions.isEmpty {
                        calendarBanner
                    }

                    if viewModel.isLoading && viewModel.contacts.isEmpty {
                        loadingState
                    } else if let error = viewModel.error, viewModel.contacts.isEmpty {
                        errorState(error: error)
                    } else if viewModel.filteredContacts.isEmpty {
                        ScrollView {
                            emptyState
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                        }
                        .refreshable { await viewModel.loadContacts() }
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
                    HStack(spacing: 12) {
                        Menu {
                            ForEach(ContactSortOrder.allCases, id: \.self) { order in
                                Button {
                                    viewModel.sortOrder = order
                                } label: {
                                    if viewModel.sortOrder == order {
                                        Label(order.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(order.rawValue)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundStyle(Color.pingTextPrimary)
                        }

                        Button {
                            isGridView.toggle()
                        } label: {
                            Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                                .foregroundStyle(Color.pingTextPrimary)
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search by name, company, notes…")
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureView(viewModel: viewModel)
            }
            .sheet(isPresented: $showCalendarSuggestions) {
                CalendarSuggestionsSheet()
                    .environment(googleState)
            }
            .task {
                guard !hasLoadedOnce else { return }
                await viewModel.loadContacts()
                if viewModel.error == nil {
                    hasLoadedOnce = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .contactsDidImport)) { _ in
                Task { await viewModel.loadContacts() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showQuickCapture)) { _ in
                showQuickCapture = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task { await viewModel.loadContacts() }
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
                    .foregroundStyle(Color.pingTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.pingAccentLight)
        }
        .buttonStyle(.plain)
    }

    private var listContent: some View {
        List {
            ForEach(viewModel.filteredContacts) { contact in
                NavigationLink(destination: ContactDetailView(contact: contact, onContactUpdated: { updated in
                    if let idx = viewModel.contacts.firstIndex(where: { $0.id == updated.id }) {
                        viewModel.contacts[idx] = updated
                    }
                })) {
                    ContactRowView(contact: contact)
                }
                .listRowBackground(Color.pingBackground)
                .listRowSeparatorTint(Color.pingSurface3)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteContact(contact) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.loadContacts() }
    }

    private var gridContent: some View {
        ScrollView {
            ContactCardGridView(contacts: viewModel.filteredContacts)
                .padding(.top, 8)
        }
        .refreshable { await viewModel.loadContacts() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 44))
                .foregroundStyle(Color.pingTextSecondary)
            Text("Your network starts here.")
                .font(.headline)
                .foregroundStyle(Color.pingTextPrimary)
            Text("Every great relationship starts with a name.")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
                .multilineTextAlignment(.center)
            PingButton(title: "Add Contact", action: {
                showQuickCapture = true
            }, style: .primary)
            .frame(maxWidth: 200)
        }
        .padding(.horizontal, 40)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Loading your contacts…")
                .font(.subheadline)
                .foregroundStyle(Color.pingTextMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorState(error: Error) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(Color.pingDestructive)
            Text("Couldn't load your network")
                .font(.headline)
                .foregroundStyle(Color.pingTextPrimary)
            Text(userFacingMessage(for: error))
                .font(.subheadline)
                .foregroundStyle(Color.pingTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            PingButton(title: "Try Again") {
                Task { await viewModel.loadContacts() }
            }
            .frame(maxWidth: 180)
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
