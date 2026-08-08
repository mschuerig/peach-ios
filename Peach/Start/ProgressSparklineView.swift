import SwiftUI

struct ProgressSparklineView: View {
    let state: TrainingDisciplineState
    let bucketMeans: [Double]
    let ewma: Double?
    let trend: Trend?
    let config: TrainingDisciplineConfig

    var body: some View {
        switch state {
        case .noData:
            EmptyView()
        case .active:
            sparklineContent
        }
    }

    private var sparklineContent: some View {
        HStack(spacing: 6) {
            if bucketMeans.count >= 2 {
                SparklinePath(values: bucketMeans)
                    .stroke(Self.sparklineColor(for: trend), lineWidth: 1.5)
                    .frame(width: 60, height: 24)
            }
            if let ewma {
                Text(Self.formatCompactEWMA(ewma, unitSymbol: config.unitSymbol))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
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

    static func formatCompactEWMA(_ value: Double, unitSymbol: String) -> String {
        "\(MetricValueFormatter.format(value)) \(unitSymbol)"
    }

    /// Spoken description of the card's progress, used as the training card's
    /// accessibility *value*. The card itself supplies the discipline name as
    /// its accessibility label, so the name is deliberately not repeated here.
    ///
    /// Returns `nil` when there is nothing to announce, so the card exposes no
    /// value rather than a fabricated one: `ewma` is absent before any data
    /// exists, and `trend` is absent until a second record arrives.
    static func sparklineAccessibilityValue(ewma: Double?, trend: Trend?, unitLabel: String) -> String? {
        guard let ewma else { return nil }
        let value = "\(MetricValueFormatter.format(ewma)) \(unitLabel)"
        guard let trend else { return value }
        return "\(value), \(TrainingStatsView.trendLabel(trend))"
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
