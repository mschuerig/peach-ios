import Foundation

/// Pre-computed chart data model for progress visualization.
///
/// Separates data preparation from rendering: all positions, zones,
/// line data, and layout metadata are computed once at construction
/// and consumed by `ProgressChartView` and `ExportChartView`.
struct ChartData {

    let buckets: [TimeBucket]
    let positions: [Double]
    let yDomain: ClosedRange<Double>
    let separatorData: ZoneSeparatorData
    let yearLabels: [YearLabel]
    let lineData: [LinePoint]
    let axisValues: [Double]
    let totalExtent: Double
    let needsScrolling: Bool

    init(buckets: [TimeBucket]) {
        self.buckets = buckets
        self.positions = Self.chartPositions(for: buckets)
        self.yDomain = Self.yDomain(for: buckets)
        let boundaries = ChartLayoutCalculator.zoneBoundaries(for: buckets)
        self.separatorData = Self.zoneSeparatorData(for: buckets, boundaries: boundaries)
        self.yearLabels = Self.yearLabels(for: buckets, boundaries: boundaries)
        self.lineData = Self.lineDataWithSessionBridge(for: buckets, positions: self.positions)
        self.axisValues = Self.axisMarkPositions(buckets: buckets, positions: self.positions)
        self.totalExtent = (self.positions.last ?? -0.5) + 0.5
        self.needsScrolling = self.totalExtent > Double(Self.visibleBucketCount)
    }

    // MARK: - Constants

    static let sessionSpacing: Double = 0.3
    static let visibleBucketCount = 8

    // MARK: - Supporting Types

    struct LinePoint {
        let position: Double
        let mean: Double
        let stddev: Double
    }

    struct ZoneInfo: Identifiable {
        let bucketSize: BucketSize
        let startIndex: Int
        let endIndex: Int

        var id: String { "\(bucketSize):\(startIndex)" }
    }

    struct YearLabel: Identifiable {
        let year: Int
        let firstIndex: Int
        let lastIndex: Int

        var id: String { "\(year):\(firstIndex)" }
    }

    struct ZoneSeparatorData {
        let zones: [ZoneInfo]
        let dividerIndices: [Int]
    }

    // MARK: - Chart Positions

    static func chartPositions(for buckets: [TimeBucket]) -> [Double] {
        guard !buckets.isEmpty else { return [] }
        var positions = [0.0]
        for i in 1..<buckets.count {
            let spacing = (buckets[i - 1].bucketSize == .session && buckets[i].bucketSize == .session) ? sessionSpacing : 1.0
            positions.append(positions[i - 1] + spacing)
        }
        return positions
    }

    // MARK: - Y Domain

    static func yDomain(for buckets: [TimeBucket]) -> ClosedRange<Double> {
        guard !buckets.isEmpty else { return 0...1 }
        let rawMax = buckets.map { $0.mean + $0.stddev }.max() ?? 1
        let yMax = max(1, rawMax)
        return 0...yMax
    }

    // MARK: - Line Data with Session Bridge

    static func lineDataWithSessionBridge(for buckets: [TimeBucket], positions: [Double]) -> [LinePoint] {
        var points: [LinePoint] = []
        for (i, bucket) in buckets.enumerated() where bucket.bucketSize != .session {
            points.append(LinePoint(position: positions[i], mean: bucket.mean, stddev: bucket.stddev))
        }
        let sessionBuckets = buckets.enumerated().filter { $0.element.bucketSize == .session }
        if let first = sessionBuckets.first {
            let totalRecords = sessionBuckets.map(\.element.recordCount).reduce(0, +)
            if totalRecords > 0 {
                let mean = sessionBuckets.map { $0.element.mean * Double($0.element.recordCount) }.reduce(0, +) / Double(totalRecords)
                let weightedVariance = sessionBuckets.map { pow($0.element.stddev, 2) * Double($0.element.recordCount) }.reduce(0, +) / Double(totalRecords)
                let bridgePos = zoneEdgeBefore(index: first.offset, positions: positions)
                points.append(LinePoint(position: bridgePos, mean: mean, stddev: sqrt(weightedVariance)))
            }
        }
        return points
    }

    // MARK: - Zone Separator Data

    static func zoneSeparatorData(for buckets: [TimeBucket]) -> ZoneSeparatorData {
        zoneSeparatorData(for: buckets, boundaries: ChartLayoutCalculator.zoneBoundaries(for: buckets))
    }

    static func zoneSeparatorData(for buckets: [TimeBucket], boundaries: [ZoneBoundary]) -> ZoneSeparatorData {

        guard boundaries.count > 1 else {
            return ZoneSeparatorData(zones: [], dividerIndices: [])
        }

        let zones = boundaries.map { boundary in
            ZoneInfo(
                bucketSize: boundary.bucketSize,
                startIndex: boundary.startIndex,
                endIndex: boundary.endIndex
            )
        }

        var dividerIndices = boundaries.dropFirst().map(\.startIndex)

        let calendar = Calendar.current
        for boundary in boundaries where boundary.bucketSize == .month && boundary.endIndex > boundary.startIndex {
            for i in (boundary.startIndex + 1)...boundary.endIndex {
                let prevYear = calendar.component(.year, from: buckets[i - 1].periodStart)
                let currYear = calendar.component(.year, from: buckets[i].periodStart)
                if currYear != prevYear {
                    let isNearZoneTransition = dividerIndices.contains { abs($0 - i) <= 1 }
                    if !isNearZoneTransition {
                        dividerIndices.append(i)
                    }
                }
            }
        }

        dividerIndices.sort()

        return ZoneSeparatorData(zones: zones, dividerIndices: dividerIndices)
    }

    // MARK: - Year Labels

    static func yearLabels(for buckets: [TimeBucket]) -> [YearLabel] {
        yearLabels(for: buckets, boundaries: ChartLayoutCalculator.zoneBoundaries(for: buckets))
    }

    static func yearLabels(for buckets: [TimeBucket], boundaries: [ZoneBoundary]) -> [YearLabel] {
        let calendar = Calendar.current
        var labels: [YearLabel] = []

        for boundary in boundaries where boundary.bucketSize == .month {
            var currentYear = calendar.component(.year, from: buckets[boundary.startIndex].periodStart)
            var spanStart = boundary.startIndex

            if boundary.endIndex > boundary.startIndex {
                for i in (boundary.startIndex + 1)...boundary.endIndex {
                    let year = calendar.component(.year, from: buckets[i].periodStart)
                    if year != currentYear {
                        labels.append(YearLabel(year: currentYear, firstIndex: spanStart, lastIndex: i - 1))
                        currentYear = year
                        spanStart = i
                    }
                }
            }
            labels.append(YearLabel(year: currentYear, firstIndex: spanStart, lastIndex: boundary.endIndex))
        }

        return labels
    }

    // MARK: - Axis Mark Positions

    static func axisMarkPositions(buckets: [TimeBucket], positions: [Double]) -> [Double] {
        buckets.enumerated().compactMap { i, bucket -> Double? in
            if bucket.bucketSize != .session { return positions[i] }
            let isFirst = i == 0 || buckets[i - 1].bucketSize != .session
            return isFirst ? positions[i] : nil
        }
    }

    // MARK: - Position Helpers

    static func zoneEdgeBefore(index: Int, positions: [Double]) -> Double {
        if index == 0 { return positions[0] - 0.5 }
        return (positions[index - 1] + positions[index]) / 2.0
    }

    static func zoneEdgeAfter(index: Int, positions: [Double]) -> Double {
        if index >= positions.count - 1 { return positions[index] + 0.5 }
        return (positions[index] + positions[index + 1]) / 2.0
    }

    // MARK: - Bucket Lookup

    static func bucketIndex(nearPosition pos: Double, in positions: [Double]) -> Int? {
        guard !positions.isEmpty else { return nil }
        var best = 0
        for i in 1..<positions.count {
            if abs(positions[i] - pos) < abs(positions[best] - pos) {
                best = i
            }
        }
        return abs(positions[best] - pos) < 0.01 ? best : nil
    }

    static func findNearestBucketIndex(atX x: Double, positions: [Double]) -> Int? {
        guard !positions.isEmpty else { return nil }
        var best = 0
        for i in 1..<positions.count {
            if abs(positions[i] - x) < abs(positions[best] - x) {
                best = i
            }
        }
        return best
    }

    static func initialScrollPosition(for positions: [Double]) -> Double {
        guard let last = positions.last else { return 0 }
        return max(0, last + 0.5 - Double(visibleBucketCount))
    }
}
