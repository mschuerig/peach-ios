import SwiftUI

struct ProgressSparklineView: View {
    let mode: TrainingDisciplineID

    @Environment(\.progressTimeline) private var progressTimeline

    var body: some View {
        let state = progressTimeline.state(for: mode)
        switch state {
        case .noData:
            EmptyView()
        case .active:
            sparklineContent
        }
    }

    private var sparklineContent: some View {
        let buckets = progressTimeline.buckets(for: mode)
        let ewma = progressTimeline.currentEWMA(for: mode)
        let trend = progressTimeline.trend(for: mode)

        return HStack(spacing: 6) {
            SparklinePath(values: buckets.map(\.mean))
                .stroke(Self.sparklineColor(for: trend), lineWidth: 1.5)
                .frame(width: 60, height: 24)
            if let ewma {
                Text(Self.formatCompactEWMA(ewma))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.sparklineAccessibilityLabel(
            modeName: mode.config.displayName,
            ewma: ewma ?? 0,
            trend: trend ?? .stable,
            unitLabel: mode.config.unitLabel
        ))
    }

    // MARK: - Static Helpers

    static func sparklineColor(for trend: Trend?) -> Color {
        switch trend {
        case .improving: .green
        case .stable: .orange
        case .declining: .secondary
        case nil: .secondary
        }
    }

    static func formatCompactEWMA(_ value: Double) -> String {
        "\(Cents(value).formatted()) ¢"
    }

    static func sparklineAccessibilityLabel(modeName: String, ewma: Double, trend: Trend, unitLabel: String) -> String {
        let value = Cents(ewma).formatted()
        let trendText = TrainingStatsView.trendLabel(trend)
        return "\(modeName): \(value) \(unitLabel), \(trendText)"
    }
}

private struct SparklinePath: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count >= 2 else { return Path() }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let range = max(maxVal - minVal, 0.1)

        var path = Path()
        for (index, value) in values.enumerated() {
            let x = rect.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = rect.height * (1 - CGFloat((value - minVal) / range))
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}
