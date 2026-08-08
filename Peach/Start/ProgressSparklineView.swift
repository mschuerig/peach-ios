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
    /// Returns `nil` when there is nothing to announce, so the card can omit
    /// the modifier entirely rather than announce a fabricated value: `ewma`
    /// is absent before any data exists, and `trend` is absent until a second
    /// record arrives.
    ///
    /// The unit comes from the discipline's spelled-out ``TrainingDisciplineConfig/unitLabel``,
    /// never the compact symbol — VoiceOver reads "milliseconds" as a word and
    /// "ms" as two letters.
    static func sparklineAccessibilityValue(
        ewma: Double?,
        trend: Trend?,
        config: TrainingDisciplineConfig
    ) -> String? {
        guard let ewma else { return nil }
        let measurement = MetricValueFormatter.format(ewma)
        guard let trend else {
            return String(localized: "\(measurement) \(config.unitLabel)",
                          comment: "Spoken progress value on a Start screen training card, when no trend has been computed yet. First argument is the measured number, second is the spelled-out unit (e.g. \"cents\", \"milliseconds\").")
        }
        return String(localized: "\(measurement) \(config.unitLabel), \(TrainingStatsView.trendLabel(trend))",
                      comment: "Spoken progress value on a Start screen training card. First argument is the measured number, second the spelled-out unit (e.g. \"cents\", \"milliseconds\"), third the trend (e.g. \"Improving\").")
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
