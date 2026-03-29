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
            chartContent(buckets: buckets)
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

    private func chartContent(buckets: [TimeBucket]) -> some View {
        let yDomain = ProgressChartView.yDomain(for: buckets)
        let separatorData = ProgressChartView.zoneSeparatorData(for: buckets)
        let labels = ProgressChartView.yearLabels(for: buckets)

        let lineData = ProgressChartView.lineDataWithSessionBridge(for: buckets)

        return Chart {
            ProgressChartView.zoneBackgrounds(separatorData: separatorData, yDomain: yDomain, isIncreaseContrast: false)
            ProgressChartView.zoneDividers(separatorData: separatorData, isIncreaseContrast: false)
            ProgressChartView.stddevBand(lineData: lineData, isIncreaseContrast: false)
            ProgressChartView.ewmaLine(lineData: lineData)
            ProgressChartView.sessionDots(buckets: buckets)

            RuleMark(y: .value("Baseline", config.optimalBaseline))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(.green.opacity(0.6))
        }
        .chartXScale(domain: -0.5...Double(buckets.count) - 0.5)
        .chartYScale(domain: yDomain)
        .chartYAxisLabel(config.unitLabel)
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { value in
                if let idx = value.as(Double.self), idx >= 0, Int(idx) < buckets.count {
                    let bucket = buckets[Int(idx)]
                    AxisGridLine()
                    if bucket.bucketSize != .session {
                        AxisValueLabel {
                            Text(ProgressChartView.formatAxisLabel(
                                bucket.periodStart,
                                size: bucket.bucketSize,
                                index: Int(idx),
                                buckets: buckets
                            ))
                        }
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotAreaFrame = proxy.plotFrame {
                    let plotFrame = geometry[plotAreaFrame]

                    ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                        if let xFirst = proxy.position(forX: Double(label.firstIndex)),
                           let xLast = proxy.position(forX: Double(label.lastIndex)) {
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
        .padding(.bottom, labels.isEmpty ? 0 : 16)
    }

    // MARK: - Timestamp

    private var timestampRow: some View {
        Text(date.formatted(.dateTime.day().month(.wide).year().hour().minute()))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
