import SwiftUI
import Charts

struct ProgressChartView: View {
    let mode: TrainingDisciplineID

    @Environment(\.progressTimeline) private var progressTimeline
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @ScaledMetric(relativeTo: .caption2) private var yearLabelBottomPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var yearLabelBottomSpace: CGFloat = 16

    @State private var scrollPosition: Double = .infinity
    @State private var selectedBucketIndex: Int?
    @State private var shareImageURL: URL?

    private var config: TrainingDisciplineConfig { mode.config }
    private var isIncreaseContrast: Bool { colorSchemeContrast == .increased }

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
            chartLayout(chartData: ChartData(buckets: buckets))
                .frame(height: chartHeight)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Progress chart for \(config.displayName)"))
        .accessibilityValue(Self.chartAccessibilityValue(
            ewma: ewma,
            trend: trend,
            unitLabel: config.unitLabel
        ))
        .task(id: progressTimeline.recordCount(for: mode)) {
            shareImageURL = ChartImageRenderer.render(
                mode: mode,
                progressTimeline: progressTimeline
            )
        }
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

            if let shareURL = shareImageURL {
                ShareLink(
                    item: shareURL,
                    preview: SharePreview(config.displayName)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(String(localized: "Share \(config.displayName) chart"))
            }
        }
    }

    // MARK: - Chart Layout

    @ViewBuilder
    private func chartLayout(chartData: ChartData) -> some View {
        if chartData.needsScrolling {
            scrollableChartBody(chartData: chartData)
        } else {
            staticChartBody(chartData: chartData)
        }
    }

    private func scrollableChartBody(chartData: ChartData) -> some View {
        chartContent(chartData: chartData)
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: ChartData.visibleBucketCount)
            .chartScrollPosition(x: $scrollPosition)
            .chartGesture(selectionTapGesture(positions: chartData.positions))
            .onChange(of: scrollPosition) { _, _ in
                selectedBucketIndex = nil
            }
            .onAppear {
                scrollPosition = ChartData.initialScrollPosition(for: chartData.positions)
            }
    }

    private func staticChartBody(chartData: ChartData) -> some View {
        chartContent(chartData: chartData)
            .chartGesture(selectionTapGesture(positions: chartData.positions))
    }

    private func chartContent(chartData: ChartData) -> some View {
        Chart {
            Self.zoneBackgrounds(separatorData: chartData.separatorData, positions: chartData.positions, yDomain: chartData.yDomain, isIncreaseContrast: isIncreaseContrast)
            Self.zoneDividers(separatorData: chartData.separatorData, positions: chartData.positions, isIncreaseContrast: isIncreaseContrast)
            Self.stddevBand(lineData: chartData.lineData, isIncreaseContrast: isIncreaseContrast)
            Self.ewmaLine(lineData: chartData.lineData)
            Self.sessionDots(buckets: chartData.buckets, positions: chartData.positions)

            // Layer 6: Baseline
            RuleMark(y: .value("Baseline", config.optimalBaseline))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(.green.opacity(Self.contrastAdjustedOpacity(base: 0.6, increased: 0.9, isIncreaseContrast: isIncreaseContrast)))

            // Layer 7: Selection indicator with annotation
            if let selectedIndex = selectedBucketIndex, selectedIndex < chartData.buckets.count {
                RuleMark(x: .value("Selected", chartData.positions[selectedIndex]))
                    .foregroundStyle(Color.gray.opacity(Self.contrastAdjustedOpacity(base: 0.5, increased: 0.8, isIncreaseContrast: isIncreaseContrast)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        annotationView(for: chartData.buckets[selectedIndex])
                    }
            }
        }
        .chartXScale(domain: -0.5...chartData.totalExtent)
        .chartYScale(domain: chartData.yDomain)
        .chartYAxisLabel(config.unitLabel)
        .chartXAxis {
            AxisMarks(values: chartData.axisValues) { value in
                if let pos = value.as(Double.self),
                   let idx = ChartData.bucketIndex(nearPosition: pos, in: chartData.positions) {
                    let bucket = chartData.buckets[idx]
                    if bucket.bucketSize != .session {
                        AxisGridLine()
                    }
                    AxisValueLabel {
                        Text(Self.formatAxisLabel(
                            bucket.periodStart,
                            size: bucket.bucketSize,
                            index: idx,
                            buckets: chartData.buckets
                        ))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotAreaFrame = proxy.plotFrame {
                    let plotFrame = geometry[plotAreaFrame]

                    // Year labels below X-axis
                    ForEach(chartData.yearLabels) { label in
                        if let xFirst = proxy.position(forX: chartData.positions[label.firstIndex]),
                           let xLast = proxy.position(forX: chartData.positions[label.lastIndex]) {
                            Text(String(label.year))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .position(
                                    x: plotFrame.origin.x + (xFirst + xLast) / 2.0,
                                    y: geometry.size.height + yearLabelBottomPadding
                                )
                        }
                    }

                    // Zone accessibility containers
                    ForEach(chartData.separatorData.zones) { zone in
                        let zoneStart = ChartData.zoneEdgeBefore(index: zone.startIndex, positions: chartData.positions)
                        let zoneEnd = ChartData.zoneEdgeAfter(index: zone.endIndex, positions: chartData.positions)
                        if let summary = Self.zoneAccessibilitySummary(buckets: chartData.buckets, zone: zone, config: config),
                           let xStart = proxy.position(forX: zoneStart),
                           let xEnd = proxy.position(forX: zoneEnd) {
                            let zoneWidth = xEnd - xStart
                            let zoneCenterX = plotFrame.origin.x + (xStart + xEnd) / 2.0
                            Color.clear
                                .frame(width: zoneWidth, height: plotFrame.height)
                                .position(x: zoneCenterX, y: plotFrame.midY)
                                .accessibilityElement()
                                .accessibilityLabel(summary)
                        }
                    }
                }
            }
        }
        .padding(.bottom, chartData.yearLabels.isEmpty ? 0 : yearLabelBottomSpace)
    }

    private func selectionTapGesture(positions: [Double]) -> (ChartProxy) -> _EndedGesture<SpatialTapGesture> {
        { proxy in
            SpatialTapGesture()
                .onEnded { value in
                    guard let x: Double = proxy.value(atX: value.location.x) else {
                        selectedBucketIndex = nil
                        return
                    }
                    selectedBucketIndex = ChartData.findNearestBucketIndex(atX: x, positions: positions)
                }
        }
    }

    // MARK: - Chart Content Layers

    static func zoneBackgrounds(separatorData: ChartData.ZoneSeparatorData, positions: [Double], yDomain: ClosedRange<Double>, isIncreaseContrast: Bool) -> some ChartContent {
        ForEach(separatorData.zones) { zone in
            RectangleMark(
                xStart: .value("ZS", ChartData.zoneEdgeBefore(index: zone.startIndex, positions: positions)),
                xEnd: .value("ZE", ChartData.zoneEdgeAfter(index: zone.endIndex, positions: positions)),
                yStart: .value("Y0", yDomain.lowerBound),
                yEnd: .value("Y1", yDomain.upperBound)
            )
            .foregroundStyle(zoneTint(for: zone.bucketSize).opacity(contrastAdjustedOpacity(base: 0.06, increased: 0.12, isIncreaseContrast: isIncreaseContrast)))
        }
    }

    static func zoneDividers(separatorData: ChartData.ZoneSeparatorData, positions: [Double], isIncreaseContrast: Bool) -> some ChartContent {
        ForEach(separatorData.dividerIndices, id: \.self) { idx in
            RuleMark(x: .value("Div", ChartData.zoneEdgeBefore(index: idx, positions: positions)))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(isIncreaseContrast ? .primary : .secondary)
        }
    }

    static func stddevBand(lineData: [ChartData.LinePoint], isIncreaseContrast: Bool) -> some ChartContent {
        ForEach(lineData, id: \.position) { point in
            AreaMark(
                x: .value("Index", point.position),
                yStart: .value("Low", max(0, point.mean - point.stddev)),
                yEnd: .value("High", point.mean + point.stddev)
            )
            .foregroundStyle(.blue.opacity(contrastAdjustedOpacity(base: 0.15, increased: 0.3, isIncreaseContrast: isIncreaseContrast)))
        }
    }

    static func ewmaLine(lineData: [ChartData.LinePoint]) -> some ChartContent {
        ForEach(lineData, id: \.position) { point in
            LineMark(
                x: .value("Index", point.position),
                y: .value("EWMA", point.mean)
            )
            .foregroundStyle(.blue)
        }
    }

    static func sessionDots(buckets: [TimeBucket], positions: [Double]) -> some ChartContent {
        ForEach(Array(buckets.enumerated()), id: \.element.periodStart) { i, bucket in
            if bucket.bucketSize == .session {
                PointMark(
                    x: .value("Index", positions[i]),
                    y: .value("Value", bucket.mean)
                )
                .foregroundStyle(.blue)
                .symbolSize(20)
            }
        }
    }

    private func annotationView(for bucket: TimeBucket) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.annotationDateLabel(bucket.periodStart, size: bucket.bucketSize))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(Self.formatEWMA(bucket.mean))
                .font(.caption.bold())
            Text(Self.formatStdDev(bucket.stddev))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(localized: "\(bucket.recordCount) records"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
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

    private static func zoneTint(for bucketSize: BucketSize) -> Color {
        switch bucketSize {
        case .month: Color.platformBackground
        case .day: Color.platformSecondaryBackground
        case .session: Color.platformBackground
        }
    }

    static func annotationDateLabel(_ date: Date, size: BucketSize) -> String {
        switch size {
        case .month: date.formatted(.dateTime.month(.abbreviated).year())
        case .day: date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .session: date.formatted(.dateTime.hour().minute())
        }
    }

    static func formatAxisLabel(_ date: Date, size: BucketSize, index: Int, buckets: [TimeBucket]) -> String {
        if size == .session {
            let isFirst = index == 0 || buckets[index - 1].bucketSize != .session
            return isFirst ? String(localized: "Today") : ""
        }
        guard let config = zoneConfigs[size] else { return "" }
        var label = config.formatAxisLabel(date)
        if label.hasSuffix(".") {
            label.removeLast()
        }
        return label
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
        Cents(value).formatted()
    }

    static func formatStdDev(_ value: Double) -> String {
        "±\(Cents(value).formatted())"
    }

    static func zoneAccessibilitySummary(buckets: [TimeBucket], zone: ChartData.ZoneInfo, config: TrainingDisciplineConfig) -> String? {
        guard zone.startIndex >= 0, zone.endIndex < buckets.count, zone.startIndex <= zone.endIndex else { return nil }

        let zoneBuckets = Array(buckets[zone.startIndex...zone.endIndex])
        guard !zoneBuckets.isEmpty else { return nil }

        let zoneName: String
        switch zone.bucketSize {
        case .month: zoneName = String(localized: "Monthly")
        case .day: zoneName = String(localized: "Daily")
        case .session: zoneName = String(localized: "Session")
        }

        guard let first = zoneBuckets.first, let last = zoneBuckets.last else { return "" }
        let firstDate = annotationDateLabel(first.periodStart, size: zone.bucketSize)
        let lastDate = annotationDateLabel(last.periodStart, size: zone.bucketSize)
        let firstMean = formatEWMA(first.mean)
        let lastMean = formatEWMA(last.mean)
        let count = zoneBuckets.count

        if count == 1 {
            return String(localized: "\(zoneName) zone: \(firstDate), pitch trend \(firstMean) \(config.unitLabel), \(count) data points")
        }
        return String(localized: "\(zoneName) zone: \(firstDate) through \(lastDate), pitch trend from \(firstMean) to \(lastMean) \(config.unitLabel), \(count) data points")
    }

    static func contrastAdjustedOpacity(base: Double, increased: Double, isIncreaseContrast: Bool) -> Double {
        isIncreaseContrast ? increased : base
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
