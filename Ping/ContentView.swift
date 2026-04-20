import SwiftUI

struct ContentView: View {
    var router: NotificationRouter
    var authViewModel: AuthViewModel
    private let googleState = GoogleIntegrationState.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PingTabView(scrollToNudgeId: Binding(
                get: { router.targetNudgeId },
                set: { router.targetNudgeId = $0 }
            ))
            .tabItem {
                Label("Ping", systemImage: "bell.fill")
            }
            .tag(0)

            NetworkTabView()
                .tabItem {
                    Label("Network", systemImage: "person.2.fill")
                }
                .tag(1)

            SearchTabView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(2)

            ProfileTabView(authViewModel: authViewModel)
                .tabItem {
                    Label("You", systemImage: "person.crop.circle.fill")
                }
                .tag(3)
        }
        .tint(.pingAccent)
        .environment(googleState)
        .onChange(of: router.targetNudgeId) { _, nudgeId in
            if nudgeId != nil {
                selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showQuickCapture)) { _ in
            selectedTab = 1
        }
    }
}

#Preview {
    ContentView(router: NotificationRouter(), authViewModel: AuthViewModel())
        .environment(GoogleIntegrationState.shared)
}
