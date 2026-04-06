import Testing
import SwiftData
import Foundation
@testable import Peach

@Suite("TimingOffsetDetectionRecord Tests")
struct TimingOffsetDetectionRecordTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: TimingOffsetDetectionRecord.self, configurations: config)
    }

    // MARK: - Field Storage Tests

    @Test("Stores all fields correctly")
    func storesAllFields() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let timestamp = Date()
        let record = TimingOffsetDetectionRecord(
            tempoBPM: 120,
            offsetMs: -15.3,
            isCorrect: true,
            timestamp: timestamp
        )

        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<TimingOffsetDetectionRecord>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched[0].tempoBPM == 120)
        #expect(fetched[0].offsetMs == -15.3)
        #expect(fetched[0].isCorrect == true)
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("Default timestamp is populated")
    func defaultTimestamp() async throws {
        let before = Date()
        let record = TimingOffsetDetectionRecord(
            tempoBPM: 90,
            offsetMs: 5.0,
            isCorrect: false
        )
        let after = Date()

        #expect(record.timestamp >= before)
        #expect(record.timestamp <= after)
    }

    @Test("Stores negative offsetMs for early taps")
    func storesNegativeOffset() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let record = TimingOffsetDetectionRecord(
            tempoBPM: 100,
            offsetMs: -25.7,
            isCorrect: false
        )

        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<TimingOffsetDetectionRecord>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched[0].offsetMs == -25.7)
    }

    @Test("Stores positive offsetMs for late taps")
    func storesPositiveOffset() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let record = TimingOffsetDetectionRecord(
            tempoBPM: 100,
            offsetMs: 30.2,
            isCorrect: true
        )

        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<TimingOffsetDetectionRecord>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        #expect(fetched[0].offsetMs == 30.2)
    }

    @Test("All fields intact after save and fetch")
    func allFieldsIntactAfterSaveAndFetch() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let timestamp = Date()
        let record = TimingOffsetDetectionRecord(
            tempoBPM: 200,
            offsetMs: -0.5,
            isCorrect: true,
            timestamp: timestamp
        )

        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<TimingOffsetDetectionRecord>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let retrieved = fetched[0]
        #expect(retrieved.tempoBPM == 200)
        #expect(retrieved.offsetMs == -0.5)
        #expect(retrieved.isCorrect == true)
        #expect(abs(retrieved.timestamp.timeIntervalSince(timestamp)) < 0.001)
    }
}
