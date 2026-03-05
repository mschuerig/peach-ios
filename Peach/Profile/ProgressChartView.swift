import SwiftUI
import Charts

struct ProgressChartView: View {
    let mode: TrainingMode

    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var config: TrainingModeConfig { mode.config }

    var body: some View {
        let state = progressTimeline.state(for: mode)

        switch state {
        case .noData:
            EmptyView()
        case .coldStart(let recordsNeeded):
            coldStartCard(recordsNeeded: recordsNeeded)
        case .active:
            activeCard
        }
    }

    // MARK: - Cold Start

    private func coldStartCard(recordsNeeded: Int) -> some View {
        VStack(spacing: 8) {
            Text(config.displayName)
                .font(.headline)
            Text(Self.coldStartMessage(recordsNeeded: recordsNeeded))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Active Card

    private var activeCard: some View {
        let buckets = progressTimeline.buckets(for: mode)
        let ewma = progressTimeline.currentEWMA(for: mode)
        let trend = progressTimeline.trend(for: mode)

        return VStack(alignment: .leading, spacing: 12) {
            headlineRow(ewma: ewma, trend: trend)
            chart(buckets: buckets)
                .frame(height: chartHeight)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Progress chart for \(config.displayName)"))
        .accessibilityValue(Self.chartAccessibilityValue(
            ewma: ewma,
            trend: trend,
            unitLabel: config.unitLabel
        ))
    }

    // MARK: - Headline Row

    private func headlineRow(ewma: Double?, trend: Trend?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(config.displayName)
                .font(.headline)

            Spacer()

            if let ewma {
                Text(Self.formatEWMA(ewma))
                    .font(.title2.bold())
                Text(Self.formatStdDev(stddevForCurrentMode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let trend {
                Image(systemName: Self.trendSymbol(trend))
                    .foregroundStyle(Self.trendColor(trend))
                    .accessibilityLabel(Self.trendLabel(trend))
            }
        }
    }

    private var stddevForCurrentMode: Double {
        let buckets = progressTimeline.buckets(for: mode)
        guard let last = buckets.last else { return 0 }
        return last.stddev
    }

    // MARK: - Chart

    private func chart(buckets: [TimeBucket]) -> some View {
        let now = Date()
        return Chart {
            ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                AreaMark(
                    x: .value("Time", bucket.periodStart),
                    yStart: .value("Low", max(0, bucket.mean - bucket.stddev)),
                    yEnd: .value("High", bucket.mean + bucket.stddev)
                )
                .foregroundStyle(.blue.opacity(0.15))
            }

            ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                LineMark(
                    x: .value("Time", bucket.periodStart),
                    y: .value("EWMA", bucket.mean)
                )
                .foregroundStyle(.blue)
            }

            RuleMark(y: .value("Baseline", config.optimalBaseline.rawValue))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(.green.opacity(0.6))
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        let bucket = buckets.first { $0.periodStart == date }
                        let size = bucket?.bucketSize ?? .day
                        Text(Self.bucketLabel(for: date, size: size, relativeTo: now))
                    }
                }
            }
        }
        .chartYAxisLabel(config.unitLabel)
    }

    private var chartHeight: CGFloat {
        horizontalSizeClass == .compact ? 180 : 240
    }

    // MARK: - Static Helpers

    static func bucketLabel(for date: Date, size: BucketSize, relativeTo now: Date) -> String {
        switch size {
        case .session:
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: date, relativeTo: now)
        case .day:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .week:
            return date.formatted(.dateTime.month(.abbreviated).day())
        case .month:
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }

    static func trendSymbol(_ trend: Trend) -> String {
        switch trend {
        case .improving: "arrow.down.right"
        case .stable: "arrow.right"
        case .declining: "arrow.up.right"
        }
    }

    static func trendLabel(_ trend: Trend) -> String {
        switch trend {
        case .improving: String(localized: "Improving")
        case .stable: String(localized: "Stable")
        case .declining: String(localized: "Declining")
        }
    }

    static func trendColor(_ trend: Trend) -> Color {
        switch trend {
        case .improving: .green
        case .stable: .secondary
        case .declining: .orange
        }
    }

    static func formatEWMA(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    static func formatStdDev(_ value: Double) -> String {
        "±\(String(format: "%.1f", value))"
    }

    static func coldStartMessage(recordsNeeded: Int) -> String {
        String(localized: "Keep going! \(recordsNeeded) more sessions to see your trend")
    }

    static func chartAccessibilityValue(ewma: Double?, trend: Trend?, unitLabel: String) -> String {
        var parts: [String] = []
        if let ewma {
            parts.append(String(localized: "Current: \(Self.formatEWMA(ewma)) \(unitLabel)"))
        }
        if let trend {
            parts.append(String(localized: "trend: \(trendLabel(trend))"))
        }
        return parts.joined(separator: ", ")
    }
}
