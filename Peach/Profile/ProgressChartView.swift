import SwiftUI
import Charts

struct ProgressChartView: View {
    let mode: TrainingMode

    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var scrollPosition = Date()

    private var config: TrainingModeConfig { mode.config }

    var body: some View {
        let state = progressTimeline.state(for: mode)

        switch state {
        case .noData:
            EmptyView()
        case .active:
            activeCard
        }
    }

    // MARK: - Active Card

    private var activeCard: some View {
        let buckets = progressTimeline.allGranularityBuckets(for: mode)
        let ewma = progressTimeline.currentEWMA(for: mode)
        let trend = progressTimeline.trend(for: mode)
        let stddev = buckets.last?.stddev ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            headlineRow(ewma: ewma, stddev: stddev, trend: trend)
            chartLayout(buckets: buckets)
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

    private func headlineRow(ewma: Double?, stddev: Double, trend: Trend?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(config.displayName)
                .font(.headline)

            Spacer()

            if let ewma {
                Text(Self.formatEWMA(ewma))
                    .font(.title2.bold())
                Text(Self.formatStdDev(stddev))
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

    // MARK: - Chart Layout

    private func chartLayout(buckets: [TimeBucket]) -> some View {
        let yDomain = Self.yDomain(for: buckets)
        let needsScrolling = buckets.count > Self.visibleBucketCount

        return HStack(spacing: 0) {
            yAxisChart(yDomain: yDomain)
                .frame(width: Self.yAxisWidth)

            if needsScrolling {
                scrollableChartBody(buckets: buckets, yDomain: yDomain)
            } else {
                staticChartBody(buckets: buckets, yDomain: yDomain)
            }
        }
    }

    private func yAxisChart(yDomain: ClosedRange<Double>) -> some View {
        Chart {
            RuleMark(y: .value("Baseline", config.optimalBaseline.rawValue))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(.green.opacity(0.6))
        }
        .chartXAxis(.hidden)
        .chartYScale(domain: yDomain)
        .chartYAxisLabel(config.unitLabel)
    }

    private func scrollableChartBody(buckets: [TimeBucket], yDomain: ClosedRange<Double>) -> some View {
        let domainLength = Self.visibleDomainLength(for: buckets)
        let visibleSlice = Self.windowedSlice(
            from: buckets,
            scrollPosition: scrollPosition,
            domainLength: domainLength,
            buffer: 5
        )

        return chartContent(buckets: visibleSlice, yDomain: yDomain)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: domainLength)
            .chartScrollPosition(x: $scrollPosition)
            .onAppear {
                scrollPosition = Self.initialScrollPosition(
                    for: buckets,
                    visibleDomainLength: domainLength
                )
            }
    }

    private func staticChartBody(buckets: [TimeBucket], yDomain: ClosedRange<Double>) -> some View {
        chartContent(buckets: buckets, yDomain: yDomain)
    }

    private func chartContent(buckets: [TimeBucket], yDomain: ClosedRange<Double>) -> some View {
        let bucketSizeByDate = Dictionary(
            buckets.map { ($0.periodStart, $0.bucketSize) },
            uniquingKeysWith: { _, last in last }
        )

        return Chart {
            ForEach(buckets, id: \.periodStart) { bucket in
                AreaMark(
                    x: .value("Time", bucket.periodStart),
                    yStart: .value("Low", max(0, bucket.mean - bucket.stddev)),
                    yEnd: .value("High", bucket.mean + bucket.stddev)
                )
                .foregroundStyle(.blue.opacity(0.15))
            }

            ForEach(buckets, id: \.periodStart) { bucket in
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
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        let size = bucketSizeByDate[date] ?? .day
                        Text(Self.formatAxisLabel(date, size: size))
                    }
                }
            }
        }
    }

    private var chartHeight: CGFloat {
        horizontalSizeClass == .compact ? 180 : 240
    }

    // MARK: - Static Helpers

    static let zoneConfigs: [BucketSize: any GranularityZoneConfig] = [
        .month: MonthlyZoneConfig(),
        .day: DailyZoneConfig(),
        .session: SessionZoneConfig(),
    ]

    static func yDomain(for buckets: [TimeBucket]) -> ClosedRange<Double> {
        guard !buckets.isEmpty else { return 0...1 }
        let yMin = buckets.map { max(0, $0.mean - $0.stddev) }.min() ?? 0
        let rawMax = buckets.map { $0.mean + $0.stddev }.max() ?? 1
        let yMax = max(yMin + 1, rawMax)
        return yMin...yMax
    }

    static func windowedBuckets(from buckets: [TimeBucket], visibleRange: Range<Int>, buffer: Int) -> [TimeBucket] {
        guard !buckets.isEmpty else { return [] }
        let start = max(0, visibleRange.lowerBound - buffer)
        let end = min(buckets.count, visibleRange.upperBound + buffer)
        return Array(buckets[start..<end])
    }

    static func windowedSlice(
        from buckets: [TimeBucket],
        scrollPosition: Date,
        domainLength: TimeInterval,
        buffer: Int
    ) -> [TimeBucket] {
        guard !buckets.isEmpty else { return [] }
        let windowEnd = scrollPosition.addingTimeInterval(domainLength)
        let firstVisible = buckets.firstIndex { $0.periodStart >= scrollPosition } ?? 0
        let lastVisible = (buckets.lastIndex { $0.periodStart <= windowEnd } ?? (buckets.count - 1)) + 1
        return windowedBuckets(from: buckets, visibleRange: firstVisible..<lastVisible, buffer: buffer)
    }

    private static let visibleBucketCount = 12

    private static let yAxisWidth: CGFloat = 50

    /// Computes the time span to show in the visible window (~12 buckets worth).
    private static func visibleDomainLength(for buckets: [TimeBucket]) -> TimeInterval {
        guard buckets.count > visibleBucketCount,
              let first = buckets.first, let last = buckets.last else {
            return 86400
        }
        let totalSpan = last.periodStart.timeIntervalSince(first.periodStart)
        let ratio = Double(visibleBucketCount) / Double(buckets.count)
        return max(totalSpan * ratio, 86400)
    }

    /// Returns the date for the left edge of the initial scroll position
    /// so that the most recent data appears at the right edge.
    static func initialScrollPosition(for buckets: [TimeBucket], visibleDomainLength: TimeInterval) -> Date {
        guard let last = buckets.last else { return Date() }
        return last.periodStart.addingTimeInterval(-visibleDomainLength)
    }

    private static func formatAxisLabel(_ date: Date, size: BucketSize) -> String {
        guard let config = zoneConfigs[size] else { return "" }
        return config.formatAxisLabel(date)
    }

    static func trendSymbol(_ trend: Trend) -> String {
        TrainingStatsView.trendSymbol(trend)
    }

    static func trendLabel(_ trend: Trend) -> String {
        TrainingStatsView.trendLabel(trend)
    }

    static func trendColor(_ trend: Trend) -> Color {
        TrainingStatsView.trendColor(trend)
    }

    static func formatEWMA(_ value: Double) -> String {
        TrainingStatsView.formattedCents(value)
    }

    static func formatStdDev(_ value: Double) -> String {
        "±\(TrainingStatsView.formattedCents(value))"
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
