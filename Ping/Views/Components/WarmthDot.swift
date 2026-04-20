import SwiftUI
import Inject

struct WarmthDot: View {
    @ObserveInjection var inject
    let score: Double
    var size: CGFloat = 10
    var showLegendOnTap: Bool = false

    @State private var showLegend = false

    var color: Color { WarmthCategory(score: score).color }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .onTapGesture {
                if showLegendOnTap { showLegend = true }
            }
            .popover(isPresented: $showLegend, arrowEdge: .top) {
                warmthLegend
                    .presentationCompactAdaptation(.popover)
            }
            .enableInjection()
    }

    private var warmthLegend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Relationship Warmth")
                .font(.headline)
                .foregroundStyle(Color.pingTextPrimary)
                .padding(.bottom, 2)
            legendRow(color: .pingWarmthHot,  label: "Hot",     desc: "Actively in touch")
            legendRow(color: .pingWarmthWarm, label: "Warm",    desc: "Recent contact")
            legendRow(color: .pingWarmthCool, label: "Cooling", desc: "Worth a check-in soon")
            legendRow(color: .pingWarmthCold, label: "Cold",    desc: "Haven't connected in a while")
        }
        .padding(20)
        .frame(minWidth: 240)
    }

    private func legendRow(color: Color, label: String, desc: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Color.pingTextPrimary)
                Text(desc).font(.caption).foregroundStyle(Color.pingTextMuted)
            }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        WarmthDot(score: 0.9, showLegendOnTap: true)
        WarmthDot(score: 0.6, showLegendOnTap: true)
        WarmthDot(score: 0.3, showLegendOnTap: true)
        WarmthDot(score: 0.1, showLegendOnTap: true)
    }
    .padding()
}
