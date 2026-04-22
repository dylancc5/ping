import SwiftUI

struct DoneStep: View {
    let onFinish: () -> Void

    @State private var showParticles = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.pingAccent.opacity(0.12))
                        .frame(width: 100, height: 100)
                        .scaleEffect(showParticles ? 1.4 : 1.0)
                        .opacity(showParticles ? 0 : 1)
                        .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: showParticles)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.pingAccent)
                        .scaleEffect(showParticles ? 1.0 : 0.7)
                        .animation(.spring(duration: 0.5), value: showParticles)
                }

                VStack(spacing: 8) {
                    Text("You're all set.")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.pingTextPrimary)

                    Text("We'll nudge you when it's time to reach out.\nJust show up — Ping handles the rest.")
                        .font(.subheadline)
                        .foregroundStyle(Color.pingTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            PingButton(title: "Start using Ping", action: onFinish)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation { showParticles = true }
        }
    }
}

#Preview {
    DoneStep(onFinish: {})
        .background(Color.pingBackground)
}
