import SwiftUI
import Inject

struct WarmthDot: View {
    @ObserveInjection var inject
    let score: Double
    var size: CGFloat = 10

    var color: Color {
        switch score {
        case 0.8...: return .pingWarmthHot
        case 0.5..<0.8: return .pingWarmthWarm
        case 0.2..<0.5: return .pingWarmthCool
        default: return .pingWarmthCold
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .enableInjection()
    }
}

#Preview {
    HStack(spacing: 12) {
        WarmthDot(score: 0.9)
        WarmthDot(score: 0.6)
        WarmthDot(score: 0.3)
        WarmthDot(score: 0.1)
    }
    .padding()
}
