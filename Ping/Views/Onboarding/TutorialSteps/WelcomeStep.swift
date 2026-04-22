import SwiftUI

struct WelcomeStep: View {

    let onNext: () -> Void

    private let steps: [(icon: String, title: String, desc: String)] = [
        ("person.badge.plus", "Capture people", "Log anyone you meet — voice or type"),
        ("bell.badge.fill", "Ping reminds you", "We surface who to reach out to, before relationships fade"),
        ("wand.and.stars", "We draft the message", "AI writes it in your tone. You just hit send")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "waveform.and.person.filled")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.pingAccent)

                Text("Welcome to Ping")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.pingTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Your relationship memory, supercharged.")
                    .font(.subheadline)
                    .foregroundStyle(Color.pingTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(spacing: 16) {
                        Image(systemName: step.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(Color.pingAccent)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.pingTextPrimary)
                            Text(step.desc)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.pingTextMuted)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)

                    if i < steps.count - 1 {
                        Divider().padding(.leading, 76)
                    }
                }
            }
            .background(Color.pingSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)

            Spacer()

            PingButton(title: "Let's go →", action: onNext)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
        }
    }
}

#Preview {
    WelcomeStep(onNext: {})
        .background(Color.pingBackground)
}
