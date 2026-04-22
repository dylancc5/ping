import SwiftUI
import Inject

private struct ToneScenario {
    let step: Int
    let context: String
    let prompt: String
}

private let toneScenarios: [ToneScenario] = [
    ToneScenario(
        step: 1,
        context: "A recruiter at a company you've admired reached out on LinkedIn about a role that sounds interesting. You're open to it, but not desperate.",
        prompt: "Write 3 sentences replying to them in your natural voice."
    ),
    ToneScenario(
        step: 2,
        context: "You met someone at a networking event last week — they work in your industry and you exchanged contact info. You want to follow up and suggest grabbing coffee.",
        prompt: "Write 3 sentences reaching out to them."
    ),
    ToneScenario(
        step: 3,
        context: "A former colleague you respect just announced they started a new job. You haven't talked in a few months and want to congratulate them and stay on their radar.",
        prompt: "Write 3 sentences reaching out."
    ),
]

struct ToneSetupView: View {
    @ObserveInjection var inject
    let userId: UUID
    @ObservedObject var viewModel: AuthViewModel
    let onComplete: () -> Void

    @State private var stepIndex: Int = 0
    @State private var responses: [String] = Array(repeating: "", count: toneScenarios.count)
    @FocusState private var editorFocused: Bool

    private var scenario: ToneScenario { toneScenarios[stepIndex] }
    private var isLastStep: Bool { stepIndex == toneScenarios.count - 1 }

    private var canContinue: Bool {
        !responses[stepIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }

    var body: some View {
        ZStack {
            Color.pingBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Progress indicator
                    HStack(spacing: 6) {
                        ForEach(0..<toneScenarios.count, id: \.self) { i in
                            Capsule()
                                .fill(i <= stepIndex ? Color.pingAccent : Color.pingSurface3)
                                .frame(height: 4)
                        }
                    }
                    .padding(.bottom, 28)

                    Text("Write like yourself")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.pingTextPrimary)
                        .padding(.bottom, 6)

                    Text("Step \(scenario.step) of \(toneScenarios.count)")
                        .font(.footnote)
                        .foregroundStyle(Color.pingTextMuted)
                        .padding(.bottom, 20)

                    // Scenario context card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Scenario")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.pingAccent)
                            .padding(.bottom, 6)
                        Text(scenario.context)
                            .font(.body)
                            .foregroundStyle(Color.pingTextPrimary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.pingSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.bottom, 16)

                    Text(scenario.prompt)
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextSecondary)
                        .padding(.bottom, 10)

                    TextEditor(text: $responses[stepIndex])
                        .font(.system(size: 16))
                        .foregroundStyle(Color.pingTextPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.pingSurface2)
                        .frame(minHeight: 110)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    editorFocused ? Color.pingAccent : Color.pingSurface3,
                                    lineWidth: 1
                                )
                        )
                        .focused($editorFocused)
                        .padding(.bottom, 24)

                    PingButton(title: isLastStep ? "Finish" : "Next") {
                        Task { await advance() }
                    }
                    .disabled(!canContinue)

                    Button("Skip for now") {
                        onComplete()
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pingTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 40)
            }

            if viewModel.isLoading {
                Color.black.opacity(0.08).ignoresSafeArea()
                ProgressView()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .enableInjection()
    }

    private func advance() async {
        if isLastStep {
            let samples = responses.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            await viewModel.saveToneSamples(samples)
            if viewModel.errorMessage == nil { onComplete() }
        } else {
            withAnimation { stepIndex += 1 }
            editorFocused = false
        }
    }
}

#Preview {
    ToneSetupView(userId: UUID(), viewModel: AuthViewModel()) {}
}
