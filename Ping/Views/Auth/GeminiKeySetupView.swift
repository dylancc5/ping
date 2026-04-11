import SwiftUI
import Inject

struct GeminiKeySetupView: View {
    @ObserveInjection var inject
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pingBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Text("Add your Gemini API key")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.pingTextPrimary)
                        .padding(.bottom, 8)

                    Text("Enable AI features like message drafts")
                        .font(.body)
                        .foregroundStyle(Color.pingTextSecondary)
                        .padding(.bottom, 24)

                    SecureField("Paste your API key here", text: $apiKey)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(Color.pingTextPrimary)
                        .padding(14)
                        .background(Color.pingSurface2)
                        .cornerRadius(14)
                        .padding(.bottom, 20)

                    PingButton(title: "Save") {
                        save()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Skip") {
                        dismiss()
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pingTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)

                    Spacer()

                    Text("You can add this later in Profile → AI Settings")
                        .font(.footnote)
                        .foregroundStyle(Color.pingTextMuted)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.pingAccent)
                }
            }
        }
        .enableInjection()
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainHelper.set("GEMINI_API_KEY", value: trimmed)
        dismiss()
    }
}

#Preview {
    GeminiKeySetupView()
}
