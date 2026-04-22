import SwiftUI
import Speech
import AVFoundation

// A text field (single-line or multiline) with an embedded mic button for voice input.
// Holds its own SpeechService instance; cancels on view disappear.
// Appends transcribed text to any existing content rather than replacing it.
struct VoiceInputField: View {

    enum Style { case singleLine, multiline }

    let label: String
    let placeholder: String
    @Binding var text: String
    var style: Style = .multiline
    var minHeight: CGFloat = 80
    var isRequired: Bool = false

    @State private var speechService = SpeechService()
    @State private var isRecording = false
    @State private var recordingTask: Task<Void, Never>? = nil
    @State private var pulseScale: CGFloat = 1.0
    @State private var showPermissionAlert = false
    @State private var extractionInFlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            labelRow

            ZStack(alignment: style == .multiline ? .bottomTrailing : .trailing) {
                inputArea
                micButton
            }
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable microphone access in Settings → Ping to use voice input.")
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Subviews

    private var labelRow: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.pingTextSecondary)
            if isRequired {
                Text("*")
                    .font(.subheadline)
                    .foregroundStyle(Color.pingAccent)
            }
        }
    }

    @ViewBuilder
    private var inputArea: some View {
        if style == .multiline {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(Color.pingTextMuted)
                        .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 44))
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.body)
                    .foregroundStyle(Color.pingTextPrimary)
                    .frame(minHeight: minHeight)
                    .padding(12)
                    .padding(.trailing, 36) // room for mic button
                    .scrollContentBackground(.hidden)
            }
            .background(Color.pingSurface2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            TextField(placeholder, text: $text)
                .font(.body)
                .foregroundStyle(Color.pingTextPrimary)
                .padding(12)
                .padding(.trailing, 40) // room for mic button
                .background(Color.pingSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var micButton: some View {
        Circle()
            .fill(isRecording ? Color.pingAccent : Color.pingAccentLight)
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isRecording ? .white : Color.pingAccent)
                    .symbolEffect(.variableColor.iterative, isActive: isRecording)
            }
            .scaleEffect(pulseScale)
            .padding(style == .multiline ? 8 : 6)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !isRecording { startRecording() } }
                    .onEnded { _ in if isRecording { stopRecording() } }
            )
    }

    // MARK: - Recording Logic

    private func startRecording() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioApplication.shared.recordPermission

        if speechStatus == .notDetermined || micStatus == .undetermined {
            Task {
                await withCheckedContinuation { cont in
                    SFSpeechRecognizer.requestAuthorization { _ in cont.resume() }
                }
                await AVAudioApplication.requestRecordPermission()
                startRecording()
            }
            return
        }

        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              AVAudioApplication.shared.recordPermission == .granted else {
            showPermissionAlert = true
            return
        }

        isRecording = true
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }

        // Snapshot existing text so we can append to it
        let prefix = text.trimmingCharacters(in: .whitespacesAndNewlines)

        recordingTask = Task {
            do {
                let stream = try await speechService.startRecording()
                for await partial in stream {
                    let appended = prefix.isEmpty ? partial : "\(prefix) \(partial)"
                    text = appended
                }
            } catch {
                isRecording = false
                withAnimation { pulseScale = 1.0 }
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        speechService.stopRecording()
        recordingTask?.cancel()
        recordingTask = nil
        isRecording = false
        withAnimation { pulseScale = 1.0 }
    }
}

#Preview {
    VStack(spacing: 20) {
        VoiceInputField(
            label: "Notes",
            placeholder: "PM at Google, interested in ML infra…",
            text: .constant(""),
            style: .multiline
        )
        VoiceInputField(
            label: "How You Met",
            placeholder: "e.g. Conference, intro from Sarah…",
            text: .constant(""),
            style: .singleLine,
            isRequired: true
        )
    }
    .padding()
    .background(Color.pingBackground)
}
