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
        var firstSessionOffset: Int?
        for (i, bucket) in buckets.enumerated() {
            if bucket.bucketSize == .session {
                if firstSessionOffset == nil { firstSessionOffset = i }
            } else {
                points.append(LinePoint(position: positions[i], mean: bucket.mean, stddev: bucket.stddev))
            }
        }
        guard let firstSession = firstSessionOffset else { return points }
        let sessionBuckets = buckets[firstSession...].filter { $0.bucketSize == .session }
        let totalRecords = sessionBuckets.map(\.recordCount).reduce(0, +)
        guard totalRecords > 0 else { return points }
        let mean = sessionBuckets.map { $0.mean * Double($0.recordCount) }.reduce(0, +) / Double(totalRecords)
        let weightedVariance = sessionBuckets.map { pow($0.stddev, 2) * Double($0.recordCount) }.reduce(0, +) / Double(totalRecords)
        let bridgePos = zoneEdgeBefore(index: firstSession, positions: positions)
        // Insert bridge at correct position to maintain sort order
        let insertIndex = points.firstIndex { $0.position > bridgePos } ?? points.endIndex
        points.insert(LinePoint(position: bridgePos, mean: mean, stddev: sqrt(weightedVariance)), at: insertIndex)
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

    /// Find the bucket index whose chart position is nearest to `x`.
    /// When `tolerance` is non-nil, returns nil if the nearest position is farther than `tolerance`.
    static func nearestBucketIndex(atX x: Double, in positions: [Double], tolerance: Double? = nil) -> Int? {
        guard !positions.isEmpty else { return nil }
        var best = 0
        for i in 1..<positions.count {
            if abs(positions[i] - x) < abs(positions[best] - x) {
                best = i
            }
        }
        if let tolerance, abs(positions[best] - x) > tolerance {
            return nil
        }
        return best
    }

    static func initialScrollPosition(for positions: [Double]) -> Double {
        guard let last = positions.last else { return 0 }
        return max(0, last + 0.5 - Double(visibleBucketCount))
    }

    // MARK: - Formatting

    static let zoneConfigs: [BucketSize: any GranularityZoneConfig] = [
        .month: MonthlyZoneConfig(),
        .day: DailyZoneConfig(),
        .session: SessionZoneConfig(),
    ]

    static func formatEWMA(_ value: Double) -> String {
        Cents(value).formatted()
    }

    static func formatStdDev(_ value: Double) -> String {
        "±\(Cents(value).formatted())"
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

    static func zoneAccessibilitySummary(buckets: [TimeBucket], zone: ZoneInfo, config: TrainingDisciplineConfig) -> String? {
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
}
