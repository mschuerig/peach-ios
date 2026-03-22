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

        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 120,
            meanOffsetMs: -8.5,
            meanOffsetMsPosition0: -5.2,
            meanOffsetMsPosition1: nil,
            meanOffsetMsPosition2: 3.1,
            meanOffsetMsPosition3: nil,
            timestamp: timestamp
        )

        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<ContinuousRhythmMatchingRecord>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched[0].tempoBPM == 120)
        #expect(fetched[0].meanOffsetMs == -8.5)
        #expect(fetched[0].meanOffsetMsPosition0 == -5.2)
        #expect(fetched[0].meanOffsetMsPosition1 == nil)
        #expect(fetched[0].meanOffsetMsPosition2 == 3.1)
        #expect(fetched[0].meanOffsetMsPosition3 == nil)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("Default timestamp is populated")
    func defaultTimestamp() async throws {
        let before = Date()
        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 90,
            meanOffsetMs: 3.2
        )
        let after = Date()

        #expect(record.timestamp >= before)
        #expect(record.timestamp <= after)
    }

    @Test("All four position offsets stored and retrieved")
    func allFourPositionOffsets() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 100,
            meanOffsetMs: 2.3,
            meanOffsetMsPosition0: -3.1,
            meanOffsetMsPosition1: 1.5,
            meanOffsetMsPosition2: 7.8,
            meanOffsetMsPosition3: -0.4
        )

        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<ContinuousRhythmMatchingRecord>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched[0].meanOffsetMsPosition0 == -3.1)
        #expect(fetched[0].meanOffsetMsPosition1 == 1.5)
        #expect(fetched[0].meanOffsetMsPosition2 == 7.8)
        #expect(fetched[0].meanOffsetMsPosition3 == -0.4)
    }

    @Test("Nil position offsets default correctly")
    func nilPositionOffsets() async {
        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 80,
            meanOffsetMs: 1.0
        )

        #expect(record.meanOffsetMsPosition0 == nil)
        #expect(record.meanOffsetMsPosition1 == nil)
        #expect(record.meanOffsetMsPosition2 == nil)
        #expect(record.meanOffsetMsPosition3 == nil)
    }

    @Test("All fields intact after save and fetch")
    func allFieldsIntactAfterSaveAndFetch() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let timestamp = Date()

        let record = ContinuousRhythmMatchingRecord(
            tempoBPM: 60,
            meanOffsetMs: -0.1,
            meanOffsetMsPosition0: 2.0,
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
        #expect(retrieved.meanOffsetMsPosition0 == 2.0)
        #expect(retrieved.meanOffsetMsPosition1 == nil)
        #expect(abs(retrieved.timestamp.timeIntervalSince(timestamp)) < 0.001)
    }
}
