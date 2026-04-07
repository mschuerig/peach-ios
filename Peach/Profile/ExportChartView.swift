import SwiftUI
import Charts

struct ExportChartView: View {
    let mode: TrainingDisciplineID
    let progressTimeline: ProgressTimeline
    let date: Date

    init(mode: TrainingDisciplineID, progressTimeline: ProgressTimeline, date: Date = Date()) {
        self.mode = mode
        self.progressTimeline = progressTimeline
        self.date = date
    }

    private var config: TrainingDisciplineConfig { mode.config }

    var body: some View {
        let buckets = progressTimeline.allGranularityBuckets(for: mode)
        let ewma = progressTimeline.currentEWMA(for: mode)
        let trend = progressTimeline.trend(for: mode)
        let stddev = buckets.last?.stddev ?? 0

        VStack(alignment: .leading, spacing: 12) {
            headlineRow(ewma: ewma, stddev: stddev, trend: trend)
            timestampRow
            chartContent(chartData: ChartData(buckets: buckets))
                .frame(height: 180)
        }
        .padding()
        .frame(width: 390)
        .background(Color.platformBackground)
    }

    // MARK: - Headline Row

    private func headlineRow(ewma: Double?, stddev: Double, trend: Trend?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image("ExportIcon")
                .resizable()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }

            Text(config.displayName)
                .font(.headline)

            Spacer()

            if let ewma {
                Text(ProgressChartView.formatEWMA(ewma))
                    .font(.title2.bold())
                Text(ProgressChartView.formatStdDev(stddev))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let trend {
                Image(systemName: ProgressChartView.trendSymbol(trend))
                    .foregroundStyle(ProgressChartView.trendColor(trend))
            }
        }
    }

    // MARK: - Chart

    private func chartContent(chartData: ChartData) -> some View {
        Chart {
            ProgressChartView.zoneBackgrounds(separatorData: chartData.separatorData, positions: chartData.positions, yDomain: chartData.yDomain, isIncreaseContrast: false)
            ProgressChartView.zoneDividers(separatorData: chartData.separatorData, positions: chartData.positions, isIncreaseContrast: false)
            ProgressChartView.stddevBand(lineData: chartData.lineData, isIncreaseContrast: false)
            ProgressChartView.ewmaLine(lineData: chartData.lineData)
            ProgressChartView.sessionDots(buckets: chartData.buckets, positions: chartData.positions)

            RuleMark(y: .value("Baseline", config.optimalBaseline))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(.green.opacity(0.6))
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
                        Text(ProgressChartView.formatAxisLabel(
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

                    ForEach(chartData.yearLabels) { label in
                        if let xFirst = proxy.position(forX: chartData.positions[label.firstIndex]),
                           let xLast = proxy.position(forX: chartData.positions[label.lastIndex]) {
                            Text(String(label.year))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .position(
                                    x: plotFrame.origin.x + (xFirst + xLast) / 2.0,
                                    y: geometry.size.height + 8
                                )
                        }
                    }
                }
            }
        }
        .padding(.bottom, chartData.yearLabels.isEmpty ? 0 : 16)
    }

    // MARK: - Timestamp

    private var timestampRow: some View {
        Text(date.formatted(.dateTime.day().month(.wide).year().hour().minute()))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
