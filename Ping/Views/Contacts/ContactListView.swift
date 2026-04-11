import SwiftUI
import Inject

struct ContactListView: View {
    @ObserveInjection var inject

    var body: some View {
        // Contact list — implementation coming in Phase 2
        Color.pingBackground.ignoresSafeArea()
            .enableInjection()
    }
}

#Preview {
    ContactListView()
}
