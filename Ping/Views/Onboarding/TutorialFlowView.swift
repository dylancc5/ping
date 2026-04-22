import SwiftUI

// Main tutorial container shown once after tone setup.
// 5 steps: Welcome → Import → About You → First Capture → Done.
// Each step is skippable. Completing any step or skipping all advances.
// Dismissal sets hasCompletedTutorial = true in AuthViewModel.
struct TutorialFlowView: View {

    @ObservedObject var authViewModel: AuthViewModel
    var onComplete: () -> Void

    @State private var currentStep = 0
    @State private var capturedContact: Contact? = nil

    private let totalSteps = 5

    var body: some View {
        ZStack {
            Color.pingBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                stepContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(currentStep)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Circle()
                    .fill(i == currentStep ? Color.pingAccent : Color.pingSurface2)
                    .frame(width: i == currentStep ? 8 : 6, height: i == currentStep ? 8 : 6)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            WelcomeStep(onNext: advance)
        case 1:
            ImportStep(authViewModel: authViewModel, onNext: advance, onSkip: advance)
        case 2:
            AboutYouStep(authViewModel: authViewModel, onNext: advance, onSkip: advance)
        case 3:
            FirstCaptureStep(authViewModel: authViewModel, onNext: advance, onSkip: advance)
        default:
            DoneStep(onFinish: complete)
        }
    }

    // MARK: - Actions

    private func advance() {
        if currentStep < totalSteps - 1 {
            withAnimation { currentStep += 1 }
        } else {
            complete()
        }
    }

    private func complete() {
        authViewModel.hasCompletedTutorial = true
        onComplete()
    }
}
