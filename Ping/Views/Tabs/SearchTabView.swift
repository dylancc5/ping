import SwiftUI
import Inject

struct SearchTabView: View {
    @ObserveInjection var inject
    var authViewModel: AuthViewModel
    @State private var vm = SearchViewModel()
    @State private var networkVM = NetworkViewModel()
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.pingBackground.ignoresSafeArea()

                if vm.query.count >= 2 {
                    SemanticSearchView(viewModel: vm)
                        .transition(.opacity)
                } else {
                    GoalsPanelView(viewModel: vm, contacts: networkVM.contacts, userProfile: authViewModel.userProfile, onRefresh: {
                        await networkVM.loadContacts()
                        await vm.loadGoals(contacts: networkVM.contacts)
                    })
                        .transition(.opacity)
                }

                if let error = vm.error, !vm.isSearching {
                    errorBanner(message: userFacingMessage(for: error))
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                        .animation(.easeInOut(duration: 0.2), value: vm.error != nil)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .animation(.easeInOut(duration: 0.2), value: vm.query.count >= 2)
        }
        .searchable(text: $vm.query, prompt: "who do I know at Google in PM…")
        .onChange(of: vm.query) { _, newVal in
            vm.error = nil
            debounceTask?.cancel()
            guard newVal.count >= 2 else { return }
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await triggerSearch(query: newVal)
            }
        }
        .task {
            async let goalsLoad: () = vm.loadGoals(contacts: networkVM.contacts)
            async let contactsLoad: () = networkVM.loadContacts()
            _ = await (goalsLoad, contactsLoad)
            // Re-run goal matches once contacts are loaded so bio re-ranking has data
            if !networkVM.contacts.isEmpty {
                await vm.loadGoals(contacts: networkVM.contacts)
            }
        }
        .enableInjection()
    }

    private func triggerSearch(query: String) async {
        vm.error = nil
        do {
            let embedding = try await GeminiService.embed(query, taskType: .retrievalQuery)
            await vm.searchContacts(embeddedQuery: embedding, contacts: networkVM.contacts)
        } catch {
            vm.error = error
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Color.pingDestructive)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.pingTextPrimary)
                .lineLimit(2)
            Spacer()
            Button {
                vm.error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.pingTextMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.pingDestructive.opacity(0.1))
    }
}

#Preview {
    SearchTabView(authViewModel: AuthViewModel())
}
