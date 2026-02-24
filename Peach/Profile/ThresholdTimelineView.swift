import SwiftUI
import Charts

struct ThresholdTimelineView: View {
    @Environment(\.thresholdTimeline) private var timeline

    @State private var visibleDomainLength: TimeInterval = 7 * 24 * 3600
    @State private var selectedPoint: AggregatedDataPoint?
    @State private var selectedPosition: CGPoint = .zero

    private let minVisiblePeriods = 7
    private let defaultVisibleDomainLength: TimeInterval = 7 * 24 * 3600 // 7 days

    var body: some View {
        if timeline.dataPoints.isEmpty {
            coldStartView
        } else {
            chartView
        }
    }

    // MARK: - Cold Start

    private var coldStartView: some View {
        Text("Start training to build your profile")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Chart

    private var chartView: some View {
        let means = timeline.rollingMean()
        let stddevs = timeline.rollingStdDev()
        let aggregated = timeline.aggregatedPoints

        return Chart {
            // Layer 1 (back): StdDev band
            ForEach(Array(zip(means, stddevs).enumerated()), id: \.offset) { _, pair in
                let (mean, stddev) = pair
                AreaMark(
                    x: .value("Time", mean.date),
                    yStart: .value("Lower", max(0, mean.value - stddev.value)),
                    yEnd: .value("Upper", mean.value + stddev.value)
                )
                .foregroundStyle(.tint.opacity(0.2))
            }

            // Layer 2: Rolling mean line
            ForEach(Array(means.enumerated()), id: \.offset) { _, mean in
                LineMark(
                    x: .value("Time", mean.date),
                    y: .value("Mean", mean.value)
                )
                .foregroundStyle(.tint)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Layer 3 (front): Aggregated period points
            ForEach(Array(aggregated.enumerated()), id: \.offset) { _, point in
                PointMark(
                    x: .value("Time", point.periodStart),
                    y: .value("Cents", point.meanThreshold)
                )
                .foregroundStyle(.secondary)
                .symbolSize(9)
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(initialX: aggregated.last?.periodStart ?? Date())
        .chartXVisibleDomain(length: visibleDomainLength)
        .chartYAxisLabel("Cents")
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { tap in
                                handleTap(at: tap.location, proxy: proxy, geometry: geometry)
                            }
                    )
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                handleZoom(scale: value.magnification)
                            }
                    )
            }
        }
        .overlay {
            if let point = selectedPoint {
                detailPopup(for: point)
                    .position(selectedPosition)
            }
        }
    }

    // MARK: - Tap Handling

    private func handleTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let plotOrigin = geometry[proxy.plotFrame!].origin
        let adjustedLocation = CGPoint(x: location.x - plotOrigin.x, y: location.y - plotOrigin.y)

        guard let tappedDate: Date = proxy.value(atX: adjustedLocation.x) else {
            selectedPoint = nil
            return
        }

        let aggregated = timeline.aggregatedPoints
        let nearest = aggregated.min(by: {
            abs($0.periodStart.timeIntervalSince(tappedDate)) < abs($1.periodStart.timeIntervalSince(tappedDate))
        })

        if let nearest {
            if let pointX: CGFloat = proxy.position(forX: nearest.periodStart),
               abs(pointX - adjustedLocation.x) < 30 {
                selectedPoint = nearest
                selectedPosition = CGPoint(
                    x: pointX + plotOrigin.x,
                    y: max(80, adjustedLocation.y + plotOrigin.y - 60)
                )
            } else {
                selectedPoint = nil
            }
        } else {
            selectedPoint = nil
        }
    }

    // MARK: - Zoom Handling

    private func handleZoom(scale: CGFloat) {
        let totalSpan = totalDataSpan
        guard totalSpan > 0 else { return }

        let newDomain = defaultVisibleDomainLength / scale
        let minDomain = estimatedDomainForPeriods(minVisiblePeriods)
        visibleDomainLength = max(minDomain, min(totalSpan, newDomain))
    }

    private var totalDataSpan: TimeInterval {
        let aggregated = timeline.aggregatedPoints
        guard let first = aggregated.first,
              let last = aggregated.last else { return 0 }
        return last.periodStart.timeIntervalSince(first.periodStart)
    }

    private func estimatedDomainForPeriods(_ count: Int) -> TimeInterval {
        let aggregated = timeline.aggregatedPoints
        guard aggregated.count > 1 else { return 86400 }
        let avgInterval = totalDataSpan / Double(aggregated.count - 1)
        return avgInterval * Double(count)
    }

    // MARK: - Detail Popup

    private func detailPopup(for point: AggregatedDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(point.periodStart, format: .dateTime.month().day().year())
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text(String(format: "%.1f cents", point.meanThreshold))
                    .font(.caption.bold())
                Text(String(localized: "average"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text(String(localized: "\(point.comparisonCount) comparisons"))
                    .font(.caption)
                Text(String(localized: "\(point.correctCount) of \(point.comparisonCount) correct"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            selectedPoint = nil
        }
    }
}

#Preview("With Data") {
    ThresholdTimelineView()
        .environment(\.thresholdTimeline, {
            let records = (0..<50).map { i in
                let baseOffset = 50.0 - Double(i) * 0.5
                let noise = Double.random(in: -10...10)
                return ComparisonRecord(
                    note1: 60,
                    note2: 60,
                    note2CentOffset: baseOffset + noise,
                    isCorrect: Bool.random(),
                    timestamp: Date().addingTimeInterval(Double(i - 50) * 86400)
                )
            }
            return ThresholdTimeline(records: records)
        }())
        .frame(height: 300)
        .padding()
}

#Preview("Cold Start") {
    ThresholdTimelineView()
        .frame(height: 300)
        .padding()
}
