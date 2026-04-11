import SwiftUI
import Inject

struct QuickCaptureView: View {
    @ObserveInjection var inject
    let viewModel: NetworkViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ContactDraft()
    @State private var isRecording = false
    @State private var transcript = ""
    @State private var speechService = SpeechService()
    @State private var recordingTask: Task<Void, Never>?

    @State private var micScale: CGFloat = 1.0

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !draft.howMet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.pingTextSubtle)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    fields
                    micButton
                    if !transcript.isEmpty { transcriptPreview }
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.pingSurface.ignoresSafeArea())
        .enableInjection()
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("Log a Contact")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.pingTextPrimary)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.pingTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.pingSurface2)
                    .clipShape(Circle())
            }
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 20) {
            captureField(label: "Name", placeholder: "Marcus Chen", required: true, text: $draft.name)
            captureField(label: "Where did you meet?", placeholder: "SCET career fair", required: true, text: $draft.howMet)
            notesField
        }
    }

    private func captureField(label: String, placeholder: String, required: Bool, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pingTextSecondary)
                if required {
                    Text("*")
                        .font(.subheadline)
                        .foregroundStyle(Color.pingAccent)
                }
            }
            TextField(placeholder, text: text)
                .font(.body)
                .foregroundStyle(Color.pingTextPrimary)
                .padding(12)
                .background(Color.pingSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.pingTextSecondary)

            ZStack(alignment: .topLeading) {
                if (draft.notes ?? "").isEmpty {
                    Text("PM at Google, interested in ML infra…")
                        .font(.body)
                        .foregroundStyle(Color.pingTextMuted)
                        .padding(16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: Binding(
                    get: { draft.notes ?? "" },
                    set: { draft.notes = $0.isEmpty ? nil : $0 }
                ))
                .font(.body)
                .foregroundStyle(Color.pingTextPrimary)
                .frame(minHeight: 80)
                .padding(12)
                .scrollContentBackground(.hidden)
            }
            .background(Color.pingSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var micButton: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(isRecording ? Color.pingAccent : Color.pingAccentLight)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundStyle(isRecording ? Color.white : Color.pingAccent)
                }
                .scaleEffect(micScale)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isRecording { startRecording() }
                        }
                        .onEnded { _ in
                            if isRecording { stopRecording() }
                        }
                )
                .frame(maxWidth: .infinity)

            Text(isRecording ? "Release to stop" : "Hold to speak")
                .font(.caption)
                .foregroundStyle(Color.pingTextMuted)
        }
        .padding(.vertical, 8)
    }

    private var transcriptPreview: some View {
        Text(transcript)
            .font(.footnote)
            .foregroundStyle(Color.pingTextSecondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pingSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var saveButton: some View {
        PingButton(title: "Save Contact", action: save)
            .opacity(canSave ? 1 : 0.4)
            .disabled(!canSave)
            .padding(.top, 8)
    }

    // MARK: - Actions

    private func startRecording() {
        isRecording = true
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            micScale = 1.12
        }

        recordingTask = Task {
            do {
                let stream = try await speechService.startRecording()
                for await partial in stream {
                    transcript = partial
                }
                onRecordingFinished()
            } catch {
                isRecording = false
                micScale = 1.0
            }
        }
    }

    private func stopRecording() {
        speechService.stopRecording()
        recordingTask?.cancel()
        recordingTask = nil
        isRecording = false
        withAnimation { micScale = 1.0 }
        onRecordingFinished()
    }

    private func onRecordingFinished() {
        guard !transcript.isEmpty else { return }
        Task {
            if let extracted = try? await GeminiService.extractContactFromTranscript(transcript) {
                if draft.name.isEmpty   { draft.name    = extracted.name }
                if draft.howMet.isEmpty { draft.howMet  = extracted.howMet }
                if draft.company == nil { draft.company = extracted.company }
                if draft.title == nil   { draft.title   = extracted.title }
                if draft.notes == nil   { draft.notes   = extracted.notes }
            }
        }
    }

    private func save() {
        Task {
            await viewModel.createContact(draft)
            dismiss()
        }
    }
}

#Preview {
    Text("Network")
        .sheet(isPresented: .constant(true)) {
            QuickCaptureView(viewModel: NetworkViewModel())
                .presentationDetents([.large])
        }
}
