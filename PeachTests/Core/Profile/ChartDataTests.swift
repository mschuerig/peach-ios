import Testing
import Foundation
@testable import Peach

@Suite("ChartData Tests")
struct ChartDataTests {

    // MARK: - Construction

    @Test("constructs from buckets with all pre-computed data")
    func constructsFromBuckets() async {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let buckets = [
            TimeBucket(periodStart: base, periodEnd: base.addingTimeInterval(3600), bucketSize: .month, mean: 10, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: base.addingTimeInterval(86400), periodEnd: base.addingTimeInterval(86400 + 3600), bucketSize: .month, mean: 12, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: base.addingTimeInterval(86400 * 2), periodEnd: base.addingTimeInterval(86400 * 2 + 3600), bucketSize: .day, mean: 8, stddev: 1, recordCount: 3),
            TimeBucket(periodStart: base.addingTimeInterval(86400 * 3), periodEnd: base.addingTimeInterval(86400 * 3 + 3600), bucketSize: .day, mean: 9, stddev: 1, recordCount: 3),
            TimeBucket(periodStart: base.addingTimeInterval(86400 * 4), periodEnd: base.addingTimeInterval(86400 * 4 + 3600), bucketSize: .session, mean: 7, stddev: 1, recordCount: 1),
        ]

        let chartData = ChartData(buckets: buckets)

        #expect(chartData.buckets.count == 5)
        #expect(chartData.positions.count == 5)
        #expect(!chartData.lineData.isEmpty)
        #expect(chartData.yDomain.lowerBound == 0.0)
    }

    @Test("empty buckets produce empty chart data")
    func emptyBuckets() async {
        let chartData = ChartData(buckets: [])

        #expect(chartData.buckets.isEmpty)
        #expect(chartData.positions.isEmpty)
        #expect(chartData.lineData.isEmpty)
        #expect(chartData.separatorData.zones.isEmpty)
        #expect(chartData.yearLabels.isEmpty)
        #expect(chartData.axisValues.isEmpty)
        #expect(chartData.yDomain == 0...1)
    }

    // MARK: - Positions

    @Test("positions use session spacing for consecutive sessions")
    func sessionSpacing() async {
        let base = Date()
        let buckets = [
            TimeBucket(periodStart: base, periodEnd: base.addingTimeInterval(3600), bucketSize: .session, mean: 7, stddev: 1, recordCount: 1),
            TimeBucket(periodStart: base.addingTimeInterval(3600), periodEnd: base.addingTimeInterval(7200), bucketSize: .session, mean: 8, stddev: 1, recordCount: 1),
        ]

        let chartData = ChartData(buckets: buckets)

        #expect(chartData.positions[0] == 0.0)
        #expect(chartData.positions[1] == ChartData.sessionSpacing)
    }

    // MARK: - Line Data with Session Bridge

    @Test("line data excludes session buckets but includes bridge point")
    func lineDataSessionBridge() async {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let buckets = [
            TimeBucket(periodStart: base, periodEnd: base.addingTimeInterval(86400), bucketSize: .day, mean: 10, stddev: 2, recordCount: 5),
            TimeBucket(periodStart: base.addingTimeInterval(86400), periodEnd: base.addingTimeInterval(86400 * 2), bucketSize: .day, mean: 12, stddev: 3, recordCount: 5),
            TimeBucket(periodStart: base.addingTimeInterval(86400 * 2), periodEnd: base.addingTimeInterval(86400 * 2 + 3600), bucketSize: .session, mean: 8, stddev: 1, recordCount: 3),
            TimeBucket(periodStart: base.addingTimeInterval(86400 * 2 + 3600), periodEnd: base.addingTimeInterval(86400 * 2 + 7200), bucketSize: .session, mean: 6, stddev: 1, recordCount: 2),
        ]

        let chartData = ChartData(buckets: buckets)

        // 2 day points + 1 bridge = 3
        #expect(chartData.lineData.count == 3)
        // Day bucket positions
        #expect(chartData.lineData[0].position == 0.0)
        #expect(chartData.lineData[1].position == 1.0)
        // Bridge point: weighted mean of (8*3 + 6*2)/5 = 7.2
        let bridgePoint = chartData.lineData[2]
        #expect(abs(bridgePoint.mean - 7.2) < 0.01)
    }

    // MARK: - Total Extent

    @Test("totalExtent is half past the last position")
    func totalExtent() async {
        let base = Date()
        let buckets = [
            TimeBucket(periodStart: base, periodEnd: base.addingTimeInterval(86400), bucketSize: .day, mean: 10, stddev: 1, recordCount: 5),
            TimeBucket(periodStart: base.addingTimeInterval(86400), periodEnd: base.addingTimeInterval(86400 * 2), bucketSize: .day, mean: 12, stddev: 1, recordCount: 5),
        ]

        let chartData = ChartData(buckets: buckets)

        #expect(chartData.totalExtent == 1.5)
    }

    @Test("totalExtent is zero for empty data")
    func totalExtentEmpty() async {
        let chartData = ChartData(buckets: [])
        #expect(chartData.totalExtent == 0.0)
    }

    // MARK: - Needs Scrolling

    @Test("needs scrolling when total extent exceeds visible bucket count")
    func needsScrollingTrue() async {
        let base = Date()
        let buckets = (0..<15).map { i in
            TimeBucket(periodStart: base.addingTimeInterval(Double(i) * 86400), periodEnd: base.addingTimeInterval(Double(i + 1) * 86400), bucketSize: .day, mean: 10, stddev: 1, recordCount: 5)
        }

        let chartData = ChartData(buckets: buckets)

        #expect(chartData.needsScrolling)
    }

    @Test("does not need scrolling when few buckets")
    func needsScrollingFalse() async {
        let base = Date()
        let buckets = (0..<3).map { i in
            TimeBucket(periodStart: base.addingTimeInterval(Double(i) * 86400), periodEnd: base.addingTimeInterval(Double(i + 1) * 86400), bucketSize: .day, mean: 10, stddev: 1, recordCount: 5)
        }

        let chartData = ChartData(buckets: buckets)

        #expect(!chartData.needsScrolling)
    }
}
