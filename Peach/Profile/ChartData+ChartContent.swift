import SwiftUI
import Charts

/// Shared chart content builders used by both `ProgressChartView` and `ExportChartView`.
extension ChartData {

    // MARK: - Chart Content Layers

    static func zoneBackgrounds(separatorData: ZoneSeparatorData, positions: [Double], yDomain: ClosedRange<Double>, isIncreaseContrast: Bool) -> some ChartContent {
        ForEach(separatorData.zones) { zone in
            RectangleMark(
                xStart: .value("ZS", zoneEdgeBefore(index: zone.startIndex, positions: positions)),
                xEnd: .value("ZE", zoneEdgeAfter(index: zone.endIndex, positions: positions)),
                yStart: .value("Y0", yDomain.lowerBound),
                yEnd: .value("Y1", yDomain.upperBound)
            )
            .foregroundStyle(zoneTint(for: zone.bucketSize).opacity(contrastAdjustedOpacity(base: 0.06, increased: 0.12, isIncreaseContrast: isIncreaseContrast)))
        }
    }

    static func zoneDividers(separatorData: ZoneSeparatorData, positions: [Double], isIncreaseContrast: Bool) -> some ChartContent {
        ForEach(separatorData.dividerIndices, id: \.self) { idx in
            RuleMark(x: .value("Div", zoneEdgeBefore(index: idx, positions: positions)))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(isIncreaseContrast ? .primary : .secondary)
        }
    }

    static func stddevBand(lineData: [LinePoint], isIncreaseContrast: Bool) -> some ChartContent {
        ForEach(lineData, id: \.position) { point in
            AreaMark(
                x: .value("Index", point.position),
                yStart: .value("Low", max(0, point.mean - point.stddev)),
                yEnd: .value("High", point.mean + point.stddev)
            )
            .foregroundStyle(.blue.opacity(contrastAdjustedOpacity(base: 0.15, increased: 0.3, isIncreaseContrast: isIncreaseContrast)))
        }
    }

    static func ewmaLine(lineData: [LinePoint]) -> some ChartContent {
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

    // MARK: - Rendering Helpers

    static func contrastAdjustedOpacity(base: Double, increased: Double, isIncreaseContrast: Bool) -> Double {
        isIncreaseContrast ? increased : base
    }

    private static func zoneTint(for bucketSize: BucketSize) -> Color {
        switch bucketSize {
        case .month: Color.platformBackground
        case .day: Color.platformSecondaryBackground
        case .session: Color.platformBackground
        }
    }
}
