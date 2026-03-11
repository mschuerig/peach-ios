import Testing
import Foundation
@testable import Peach

@Suite("ChartLayoutCalculator Tests")
struct ChartLayoutCalculatorTests {

    // MARK: - Helpers

    private let now = Date()

    private func makeBucket(size: BucketSize, periodStart: Date? = nil, recordCount: Int = 1) -> TimeBucket {
        let start = periodStart ?? now
        return TimeBucket(
            periodStart: start,
            periodEnd: start.addingTimeInterval(3600),
            bucketSize: size,
            mean: 10.0,
            stddev: 1.0,
            recordCount: recordCount
        )
    }

    // MARK: - Total Width Tests

    @Test("total width for mixed zone array uses per-zone pointWidths")
    func totalWidthMixedZones() async {
        let buckets = [
            makeBucket(size: .month, periodStart: now.addingTimeInterval(-90 * 86400)),
            makeBucket(size: .month, periodStart: now.addingTimeInterval(-60 * 86400)),
            makeBucket(size: .day, periodStart: now.addingTimeInterval(-5 * 86400)),
            makeBucket(size: .day, periodStart: now.addingTimeInterval(-4 * 86400)),
            makeBucket(size: .day, periodStart: now.addingTimeInterval(-3 * 86400)),
            makeBucket(size: .session, periodStart: now.addingTimeInterval(-3600)),
        ]
        let configs: [BucketSize: any GranularityZoneConfig] = [
            .month: MonthlyZoneConfig(),
            .day: DailyZoneConfig(),
            .session: SessionZoneConfig(),
        ]
        let width = ChartLayoutCalculator.totalWidth(for: buckets, configs: configs)

        // 2 months × 30 + 3 days × 40 + 1 session × 50 = 60 + 120 + 50 = 230
        #expect(width == 230)
    }

    @Test("total width for empty array is zero")
    func totalWidthEmpty() async {
        let configs: [BucketSize: any GranularityZoneConfig] = [
            .month: MonthlyZoneConfig(),
            .day: DailyZoneConfig(),
            .session: SessionZoneConfig(),
        ]
        let width = ChartLayoutCalculator.totalWidth(for: [], configs: configs)
        #expect(width == 0)
    }

    @Test("total width for single zone")
    func totalWidthSingleZone() async {
        let buckets = [
            makeBucket(size: .session, periodStart: now.addingTimeInterval(-3600)),
            makeBucket(size: .session, periodStart: now.addingTimeInterval(-1800)),
        ]
        let configs: [BucketSize: any GranularityZoneConfig] = [
            .session: SessionZoneConfig(),
        ]
        let width = ChartLayoutCalculator.totalWidth(for: buckets, configs: configs)

        // 2 sessions × 50 = 100
        #expect(width == 100)
    }

    // MARK: - Zone Boundary Tests

    @Test("zone boundaries at correct indices for mixed zones")
    func zoneBoundariesMixed() async {
        let buckets = [
            makeBucket(size: .month, periodStart: now.addingTimeInterval(-90 * 86400)),
            makeBucket(size: .month, periodStart: now.addingTimeInterval(-60 * 86400)),
            makeBucket(size: .day, periodStart: now.addingTimeInterval(-5 * 86400)),
            makeBucket(size: .day, periodStart: now.addingTimeInterval(-4 * 86400)),
            makeBucket(size: .session, periodStart: now.addingTimeInterval(-3600)),
        ]
        let boundaries = ChartLayoutCalculator.zoneBoundaries(for: buckets)

        // 3 zones: month (0-1), day (2-3), session (4)
        #expect(boundaries.count == 3)
        #expect(boundaries[0].startIndex == 0)
        #expect(boundaries[0].endIndex == 1)
        #expect(boundaries[0].bucketSize == .month)
        #expect(boundaries[1].startIndex == 2)
        #expect(boundaries[1].endIndex == 3)
        #expect(boundaries[1].bucketSize == .day)
        #expect(boundaries[2].startIndex == 4)
        #expect(boundaries[2].endIndex == 4)
        #expect(boundaries[2].bucketSize == .session)
    }

    @Test("single zone returns one boundary with no transitions")
    func zoneBoundariesSingleZone() async {
        let buckets = [
            makeBucket(size: .day, periodStart: now.addingTimeInterval(-5 * 86400)),
            makeBucket(size: .day, periodStart: now.addingTimeInterval(-4 * 86400)),
            makeBucket(size: .day, periodStart: now.addingTimeInterval(-3 * 86400)),
        ]
        let boundaries = ChartLayoutCalculator.zoneBoundaries(for: buckets)

        #expect(boundaries.count == 1)
        #expect(boundaries[0].startIndex == 0)
        #expect(boundaries[0].endIndex == 2)
        #expect(boundaries[0].bucketSize == .day)
    }

    @Test("empty array returns no boundaries")
    func zoneBoundariesEmpty() async {
        let boundaries = ChartLayoutCalculator.zoneBoundaries(for: [])
        #expect(boundaries.isEmpty)
    }
}
