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
            let chartData = ChartData(buckets: buckets)
            chartLayout(chartData: chartData)
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
                Text(ChartData.formatEWMA(ewma))
                    .font(.title2.bold())
                Text(ChartData.formatStdDev(stddev))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let trend {
                Image(systemName: TrainingStatsView.trendSymbol(trend))
                    .foregroundStyle(TrainingStatsView.trendColor(trend))
                    .accessibilityLabel(TrainingStatsView.trendLabel(trend))
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
            ChartData.zoneBackgrounds(separatorData: chartData.separatorData, positions: chartData.positions, yDomain: chartData.yDomain, isIncreaseContrast: isIncreaseContrast)
            ChartData.zoneDividers(separatorData: chartData.separatorData, positions: chartData.positions, isIncreaseContrast: isIncreaseContrast)
            ChartData.stddevBand(lineData: chartData.lineData, isIncreaseContrast: isIncreaseContrast)
            ChartData.ewmaLine(lineData: chartData.lineData)
            ChartData.sessionDots(buckets: chartData.buckets, positions: chartData.positions)

            // Layer 6: Baseline
            RuleMark(y: .value("Baseline", config.optimalBaseline))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(.green.opacity(ChartData.contrastAdjustedOpacity(base: 0.6, increased: 0.9, isIncreaseContrast: isIncreaseContrast)))

            // Layer 7: Selection indicator with annotation
            if let selectedIndex = selectedBucketIndex, selectedIndex < chartData.buckets.count {
                RuleMark(x: .value("Selected", chartData.positions[selectedIndex]))
                    .foregroundStyle(Color.gray.opacity(ChartData.contrastAdjustedOpacity(base: 0.5, increased: 0.8, isIncreaseContrast: isIncreaseContrast)))
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
                   let idx = ChartData.nearestBucketIndex(atX: pos, in: chartData.positions, tolerance: 0.01) {
                    let bucket = chartData.buckets[idx]
                    if bucket.bucketSize != .session {
                        AxisGridLine()
                    }
                    AxisValueLabel {
                        Text(ChartData.formatAxisLabel(
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
                        if let summary = ChartData.zoneAccessibilitySummary(buckets: chartData.buckets, zone: zone, config: config),
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
                    selectedBucketIndex = ChartData.nearestBucketIndex(atX: x, in: positions)
                }
        }
    }

    private func annotationView(for bucket: TimeBucket) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ChartData.annotationDateLabel(bucket.periodStart, size: bucket.bucketSize))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(ChartData.formatEWMA(bucket.mean))
                .font(.caption.bold())
            Text(ChartData.formatStdDev(bucket.stddev))
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

    static func chartAccessibilityValue(ewma: Double?, trend: Trend?, unitLabel: String) -> String {
        var parts: [String] = []
        if let ewma {
            parts.append(String(localized: "Current: \(ChartData.formatEWMA(ewma)) \(unitLabel)"))
        }
        if let trend {
            parts.append(String(localized: "trend: \(TrainingStatsView.trendLabel(trend))"))
        }
        return parts.joined(separator: ", ")
    }
}
