import SwiftUI

struct WaveformView: View {
    let level: Float
    let recordingTime: TimeInterval

    @State private var barHeights: [CGFloat] = Array(repeating: 0.1, count: 24)

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barHeights.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: level))
                    .frame(width: 4, height: barHeights[i])
                    .animation(.easeInOut(duration: 0.1), value: barHeights[i])
            }
        }
        .frame(height: 44)
        .onChange(of: level) { _, newLevel in
            updateBars(level: newLevel)
        }
    }

    private func barColor(for level: Float) -> Color {
        switch level {
        case 0..<0.5: return .green
        case 0.5..<0.75: return .yellow
        default: return .red
        }
    }

    private func updateBars(level: Float) {
        barHeights = barHeights.dropLast().map { _ in
            let base = CGFloat(level) * 40
            let jitter = CGFloat.random(in: -8...8) * CGFloat(level)
            return max(4, min(44, base + jitter))
        }
        barHeights.insert(max(4, CGFloat(level) * 44), at: 0)
    }
}
