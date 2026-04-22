import SwiftUI

struct AboutYouStep: View {
    @ObservedObject var authViewModel: AuthViewModel
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        AboutYouEditView(
            authViewModel: authViewModel,
            onSave: onNext,
            onSkip: onSkip,
            isTutorialStep: true
        )
    }
}
