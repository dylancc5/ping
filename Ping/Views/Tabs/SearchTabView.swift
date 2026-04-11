import SwiftUI
import Inject

struct SearchTabView: View {
    @ObserveInjection var inject
    @State private var vm = SearchViewModel()
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()

                if vm.query.count >= 2 {
                    SemanticSearchView(viewModel: vm)
                } else {
                    GoalsPanelView(viewModel: vm)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
        .searchable(text: $vm.query, prompt: "who do I know at Google in PM…")
        .onChange(of: vm.query) { _, newVal in
            debounceTask?.cancel()
            guard newVal.count >= 2 else { return }
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await triggerSearch(query: newVal)
            }
        }
        .task {
            await vm.loadGoals()
        }
        .enableInjection()
    }

    private func triggerSearch(query: String) async {
        guard let embedding = try? await GeminiService.shared.embed(query, taskType: .retrievalQuery) else { return }
        await vm.searchContacts(embeddedQuery: embedding)
    }
}

#Preview {
    SearchTabView()
}
