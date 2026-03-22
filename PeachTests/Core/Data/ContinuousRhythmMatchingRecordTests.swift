import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("ContinuousRhythmMatchingRecord Tests")
struct ContinuousRhythmMatchingRecordTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ContinuousRhythmMatchingRecord.self, configurations: config)
    }

    // MARK: - Field Storage Tests

    @Test("Stores all fields correctly")
    func storesAllFields() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let timestamp = Date()
        let breakdown = [PositionBreakdown(position: 0, hitCount: 3, missCount: 1, meanOffsetMs: -5.2)]
        let breakdownJSON = try JSONEncoder().encode(breakdown)

        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 120,
            meanOffsetMs: -8.5,
            hitRate: 75.0,
            gapPositionBreakdownJSON: breakdownJSON,
            cycleCount: 4,
            timestamp: timestamp
        )

        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<ContinuousRhythmMatchingRecord>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched[0].tempoBPM == 120)
        #expect(fetched[0].meanOffsetMs == -8.5)
        #expect(fetched[0].hitRate == 75.0)
        #expect(fetched[0].gapPositionBreakdownJSON == breakdownJSON)
        #expect(fetched[0].cycleCount == 4)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("Default timestamp is populated")
    func defaultTimestamp() async throws {
        let before = Date()
        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 90,
            meanOffsetMs: 3.2,
            hitRate: 100.0,
            gapPositionBreakdownJSON: Data(),
            cycleCount: 2
        )
        let after = Date()

        #expect(record.timestamp >= before)
        #expect(record.timestamp <= after)
    }

    @Test("Gap position breakdown round-trips through JSON")
    func gapPositionBreakdownRoundTrips() async throws {
        let breakdowns = [
            PositionBreakdown(position: 0, hitCount: 5, missCount: 1, meanOffsetMs: -3.1),
            PositionBreakdown(position: 2, hitCount: 4, missCount: 2, meanOffsetMs: 7.8)
        ]
        let encoded = try JSONEncoder().encode(breakdowns)

        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 100,
            meanOffsetMs: 2.3,
            hitRate: 80.0,
            gapPositionBreakdownJSON: encoded,
            cycleCount: 6
        )

        let decoded = try JSONDecoder().decode([PositionBreakdown].self, from: record.gapPositionBreakdownJSON)
        #expect(decoded.count == 2)
        #expect(decoded[0].position == 0)
        #expect(decoded[0].hitCount == 5)
        #expect(decoded[0].missCount == 1)
        #expect(decoded[0].meanOffsetMs == -3.1)
        #expect(decoded[1].position == 2)
        #expect(decoded[1].hitCount == 4)
        #expect(decoded[1].meanOffsetMs == 7.8)
    }

    @Test("All fields intact after save and fetch")
    func allFieldsIntactAfterSaveAndFetch() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let timestamp = Date()
        let breakdownJSON = try JSONEncoder().encode([PositionBreakdown]())

        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 60,
            meanOffsetMs: -0.1,
            hitRate: 50.0,
            gapPositionBreakdownJSON: breakdownJSON,
            cycleCount: 10,
            timestamp: timestamp
        )

        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<ContinuousRhythmMatchingRecord>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let retrieved = fetched[0]
        #expect(retrieved.tempoBPM == 60)
        #expect(retrieved.meanOffsetMs == -0.1)
        #expect(retrieved.hitRate == 50.0)
        #expect(retrieved.cycleCount == 10)
        #expect(abs(retrieved.timestamp.timeIntervalSince(timestamp)) < 0.001)
    }
}
