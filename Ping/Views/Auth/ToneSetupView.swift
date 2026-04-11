import SwiftUI
import Inject

struct ToneSetupView: View {
    @ObserveInjection var inject
    let userId: UUID
    @ObservedObject var viewModel: AuthViewModel
    let onComplete: () -> Void

    @State private var sampleText: String = ""
    @FocusState private var editorFocused: Bool

    private var canContinue: Bool {
        !sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }

    var body: some View {
        ZStack {
            Color.pingBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("How do you usually write?")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.pingTextPrimary)
                        .padding(.bottom, 8)

                    Text("Paste 2–3 sentences in your own voice")
                        .font(.body)
                        .foregroundStyle(Color.pingTextSecondary)
                        .padding(.bottom, 4)

                    Text("Only used to calibrate drafts, never shared")
                        .font(.footnote)
                        .foregroundStyle(Color.pingTextMuted)
                        .padding(.bottom, 20)

                    TextEditor(text: $sampleText)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.pingTextPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.pingSurface2)
                        .frame(minHeight: 80)
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

                    PingButton(title: "Continue") {
                        Task { await save() }
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

    private func save() async {
        let trimmed = sampleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await viewModel.saveToneSample(trimmed)
        if viewModel.errorMessage == nil {
            onComplete()
        }
    }
}

#Preview {
    ToneSetupView(userId: UUID(), viewModel: AuthViewModel()) {}
}
