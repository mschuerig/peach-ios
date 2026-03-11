import Testing
import Foundation
@testable import Peach

@Suite("ProgressChartView Tests")
struct ProgressChartViewTests {

    // MARK: - Y-Domain Computation

    @Test("computes Y domain from bucket min/max with stddev")
    func yDomainFromBuckets() async {
        let buckets = [
            TimeBucket(periodStart: Date(), periodEnd: Date(), bucketSize: .month, mean: 20.0, stddev: 5.0, recordCount: 10),
            TimeBucket(periodStart: Date(), periodEnd: Date(), bucketSize: .day, mean: 10.0, stddev: 3.0, recordCount: 5),
            TimeBucket(periodStart: Date(), periodEnd: Date(), bucketSize: .session, mean: 30.0, stddev: 8.0, recordCount: 3),
        ]
        let domain = ProgressChartView.yDomain(for: buckets)
        // yMin = max(0, min(20-5, 10-3, 30-8)) = max(0, 7) = 7
        // yMax = max(20+5, 10+3, 30+8) = 38
        #expect(domain.lowerBound == 7.0)
        #expect(domain.upperBound == 38.0)
    }

    @Test("Y domain clamps lower bound to zero")
    func yDomainClampsToZero() async {
        let buckets = [
            TimeBucket(periodStart: Date(), periodEnd: Date(), bucketSize: .month, mean: 2.0, stddev: 5.0, recordCount: 10),
        ]
        let domain = ProgressChartView.yDomain(for: buckets)
        // yMin = max(0, 2-5) = max(0, -3) = 0
        // yMax = 2+5 = 7
        #expect(domain.lowerBound == 0.0)
        #expect(domain.upperBound == 7.0)
    }

    @Test("Y domain for empty buckets returns 0...1")
    func yDomainEmptyBuckets() async {
        let domain = ProgressChartView.yDomain(for: [])
        #expect(domain.lowerBound == 0.0)
        #expect(domain.upperBound == 1.0)
    }

    @Test("Y domain for single bucket with zero stddev")
    func yDomainSingleBucketZeroStddev() async {
        let buckets = [
            TimeBucket(periodStart: Date(), periodEnd: Date(), bucketSize: .day, mean: 15.0, stddev: 0.0, recordCount: 1),
        ]
        let domain = ProgressChartView.yDomain(for: buckets)
        #expect(domain.lowerBound == 15.0)
        #expect(domain.upperBound == 16.0)
    }

    // MARK: - Data Windowing

    @Test("windowed slice returns correct subset with buffer")
    func windowedSliceWithBuffer() async {
        let buckets = makeBucketArray(count: 50)
        let result = ProgressChartView.windowedBuckets(from: buckets, visibleRange: 30..<40, buffer: 5)
        // Should include indices 25..<45
        #expect(result.count == 20)
        #expect(result.first?.mean == 25.0)
        #expect(result.last?.mean == 44.0)
    }

    @Test("windowed slice clamps at start boundary")
    func windowedSliceClampsAtStart() async {
        let buckets = makeBucketArray(count: 50)
        let result = ProgressChartView.windowedBuckets(from: buckets, visibleRange: 0..<5, buffer: 5)
        // Should include indices 0..<10
        #expect(result.count == 10)
        #expect(result.first?.mean == 0.0)
    }

    @Test("windowed slice clamps at end boundary")
    func windowedSliceClampsAtEnd() async {
        let buckets = makeBucketArray(count: 50)
        let result = ProgressChartView.windowedBuckets(from: buckets, visibleRange: 45..<50, buffer: 5)
        // Should include indices 40..<50
        #expect(result.count == 10)
        #expect(result.last?.mean == 49.0)
    }

    @Test("windowed slice with fewer buckets than buffer returns all")
    func windowedSliceFewBuckets() async {
        let buckets = makeBucketArray(count: 8)
        let result = ProgressChartView.windowedBuckets(from: buckets, visibleRange: 2..<6, buffer: 5)
        // Buffer would extend beyond bounds, so clamp: 0..<8 = all
        #expect(result.count == 8)
    }

    @Test("windowed slice with empty buckets returns empty")
    func windowedSliceEmpty() async {
        let result = ProgressChartView.windowedBuckets(from: [], visibleRange: 0..<0, buffer: 5)
        #expect(result.isEmpty)
    }

    // MARK: - Zone Config Dictionary

    @Test("zone configs contains month, day, and session")
    func zoneConfigsContainsExpectedKeys() async {
        let configs = ProgressChartView.zoneConfigs
        #expect(configs[.month] != nil)
        #expect(configs[.day] != nil)
        #expect(configs[.session] != nil)
    }

    @Test("zone configs does not contain week")
    func zoneConfigsExcludesWeek() async {
        let configs = ProgressChartView.zoneConfigs
        #expect(configs[.week] == nil)
    }

    @Test("zone config point widths match expected values")
    func zoneConfigPointWidths() async {
        let configs = ProgressChartView.zoneConfigs
        #expect(configs[.month]?.pointWidth == 30)
        #expect(configs[.day]?.pointWidth == 40)
        #expect(configs[.session]?.pointWidth == 50)
    }

    // MARK: - Windowed Slice from Scroll Position

    @Test("windowed slice from scroll position returns correct range with buffer")
    func windowedSliceFromScrollPosition() async {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let buckets = (0..<50).map { i in
            TimeBucket(
                periodStart: base.addingTimeInterval(Double(i) * 86400),
                periodEnd: base.addingTimeInterval(Double(i) * 86400 + 3600),
                bucketSize: .day,
                mean: Double(i),
                stddev: 1.0,
                recordCount: 5
            )
        }
        let scrollPos = base.addingTimeInterval(20 * 86400)
        let result = ProgressChartView.windowedSlice(
            from: buckets,
            scrollPosition: scrollPos,
            domainLength: 10 * 86400,
            buffer: 5
        )
        // Visible: indices 20-30, with buffer 5: indices 15-35
        #expect(result.first?.mean == 15.0)
        #expect(result.last?.mean == 35.0)
    }

    @Test("windowed slice from scroll position with empty buckets returns empty")
    func windowedSliceFromScrollPositionEmpty() async {
        let result = ProgressChartView.windowedSlice(
            from: [],
            scrollPosition: Date(),
            domainLength: 86400,
            buffer: 5
        )
        #expect(result.isEmpty)
    }

    // MARK: - Initial Scroll Position

    @Test("initial scroll position places latest data at right edge")
    func initialScrollPositionPinsRight() async {
        let now = Date()
        let buckets = [
            TimeBucket(periodStart: now.addingTimeInterval(-86400 * 30), periodEnd: now.addingTimeInterval(-86400 * 29), bucketSize: .month, mean: 10.0, stddev: 1.0, recordCount: 5),
            TimeBucket(periodStart: now, periodEnd: now, bucketSize: .session, mean: 15.0, stddev: 2.0, recordCount: 3),
        ]
        let domainLength: TimeInterval = 86400 * 10
        let position = ProgressChartView.initialScrollPosition(for: buckets, visibleDomainLength: domainLength)
        // Left edge should be latestDate - domainLength
        let expected = now.addingTimeInterval(-domainLength)
        #expect(abs(position.timeIntervalSince(expected)) < 0.001)
    }

    // MARK: - Trend Display

    @Test("trend symbol for improving is arrow.down.right")
    func trendSymbolImproving() async {
        #expect(ProgressChartView.trendSymbol(.improving) == "arrow.down.right")
    }

    @Test("trend symbol for stable is arrow.right")
    func trendSymbolStable() async {
        #expect(ProgressChartView.trendSymbol(.stable) == "arrow.right")
    }

    @Test("trend symbol for declining is arrow.up.right")
    func trendSymbolDeclining() async {
        #expect(ProgressChartView.trendSymbol(.declining) == "arrow.up.right")
    }

    @Test("trend label for improving")
    func trendLabelImproving() async {
        let label = ProgressChartView.trendLabel(.improving)
        #expect(!label.isEmpty)
    }

    // MARK: - EWMA Formatting

    @Test("formats EWMA value with one decimal place")
    func formatEWMA() async {
        let formatted = ProgressChartView.formatEWMA(23.456)
        #expect(formatted.contains("23.5") || formatted.contains("23,5"))
    }

    @Test("formats stddev with plus-minus prefix")
    func formatStdDev() async {
        let formatted = ProgressChartView.formatStdDev(5.78)
        #expect(formatted.contains("±"))
    }

    // MARK: - Accessibility

    @Test("chart accessibility value includes EWMA and trend")
    func chartAccessibilityValue() async {
        let value = ProgressChartView.chartAccessibilityValue(
            ewma: 25.3,
            trend: .improving,
            unitLabel: "cents"
        )
        #expect(!value.isEmpty)
    }

    // MARK: - Helpers

    private func makeBucketArray(count: Int) -> [TimeBucket] {
        let now = Date()
        return (0..<count).map { i in
            TimeBucket(
                periodStart: now.addingTimeInterval(Double(i) * -86400),
                periodEnd: now.addingTimeInterval(Double(i) * -86400 + 3600),
                bucketSize: .day,
                mean: Double(i),
                stddev: 1.0,
                recordCount: 5
            )
        }
    }

}
