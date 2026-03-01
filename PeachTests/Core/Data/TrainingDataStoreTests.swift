import Testing
import SwiftData
import Foundation
@testable import Peach

/// Core CRUD and persistence tests for TrainingDataStore
@Suite("TrainingDataStore Tests")
struct TrainingDataStoreTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self, configurations: config)
    }

    private func makeFileBasedContainer() throws -> ModelContainer {
        let tempDir = FileManager.default.temporaryDirectory
        let config = ModelConfiguration(url: tempDir.appendingPathComponent("test-\(UUID().uuidString).store"))
        return try ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self, configurations: config)
    }

    // MARK: - Save and Fetch Tests

    @Test("Save and retrieve a single record")
    func saveAndRetrieveSingleRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = ComparisonRecord(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 50.0,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament",
            timestamp: Date()
        )

        try store.save(record)

        let fetched = try store.fetchAllComparisons()

        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 60)
        #expect(fetched[0].centOffset == 50.0)
        #expect(fetched[0].isCorrect == true)
        #expect(fetched[0].interval == 0)
        #expect(fetched[0].tuningSystem == "equalTemperament")
    }

    @Test("FetchAll returns multiple records in timestamp order")
    func fetchMultipleRecordsInOrder() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let now = Date()
        let record1 = ComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: now.addingTimeInterval(-60))
        let record2 = ComparisonRecord(referenceNote: 62, targetNote: 62, centOffset: 20.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament", timestamp: now.addingTimeInterval(-30))
        let record3 = ComparisonRecord(referenceNote: 64, targetNote: 64, centOffset: 30.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: now)

        try store.save(record1)
        try store.save(record2)
        try store.save(record3)

        let fetched = try store.fetchAllComparisons()

        #expect(fetched.count == 3)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[1].referenceNote == 62)
        #expect(fetched[2].referenceNote == 64)
    }

    @Test("All fields remain intact after save and retrieval")
    func allFieldsIntact() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let record = ComparisonRecord(
            referenceNote: 72,
            targetNote: 72,
            centOffset: 123.45,
            isCorrect: false,
            interval: 0,
            tuningSystem: "equalTemperament",
            timestamp: timestamp
        )

        try store.save(record)

        let fetched = try store.fetchAllComparisons()

        #expect(fetched.count == 1)
        let retrieved = fetched[0]
        #expect(retrieved.referenceNote == 72)
        #expect(retrieved.targetNote == 72)
        #expect(retrieved.centOffset == 123.45)
        #expect(retrieved.isCorrect == false)
        #expect(retrieved.interval == 0)
        #expect(retrieved.tuningSystem == "equalTemperament")
        #expect(abs(retrieved.timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    // MARK: - Delete Tests

    @Test("Delete removes record")
    func deleteRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = ComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(record)

        var fetched = try store.fetchAllComparisons()
        #expect(fetched.count == 1)

        try store.delete(record)

        fetched = try store.fetchAllComparisons()
        #expect(fetched.isEmpty)
    }

    @Test("Delete only removes specified record")
    func deleteSpecificRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record1 = ComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        let record2 = ComparisonRecord(referenceNote: 62, targetNote: 62, centOffset: 20.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament")
        try store.save(record1)
        try store.save(record2)

        try store.delete(record1)

        let fetched = try store.fetchAllComparisons()
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 62)
    }

    // MARK: - Persistence Tests

    @Test("Records persist across context recreation (simulated restart)")
    func persistenceAcrossRestart() async throws {
        let container = try makeFileBasedContainer()

        do {
            let context1 = ModelContext(container)
            let store1 = TrainingDataStore(modelContext: context1)

            let record = ComparisonRecord(
                referenceNote: 69,
                targetNote: 69,
                centOffset: 75.0,
                isCorrect: true,
                interval: 0,
                tuningSystem: "equalTemperament"
            )
            try store1.save(record)
        }

        let context2 = ModelContext(container)
        let store2 = TrainingDataStore(modelContext: context2)

        let fetched = try store2.fetchAllComparisons()

        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 69)
        #expect(fetched[0].centOffset == 75.0)
    }

    // MARK: - Atomic Write Tests

    @Test("Atomic write behavior - successful save is complete")
    func atomicWriteSuccess() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = ComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(record)

        let fetched = try store.fetchAllComparisons()
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 60)
        #expect(fetched[0].centOffset == 10.0)
        #expect(fetched[0].isCorrect == true)
    }

    // MARK: - Empty Store Tests

    @Test("FetchAll returns empty array when no records exist")
    func fetchFromEmptyStore() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let fetched = try store.fetchAllComparisons()

        #expect(fetched.isEmpty)
    }

    // MARK: - Pitch Matching Save and Fetch Tests

    @Test("Save and retrieve a single pitch matching record")
    func saveAndRetrievePitchMatchingRecord() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = PitchMatchingRecord(
            referenceNote: 69,
            targetNote: 69,
            initialCentOffset: 42.5,
            userCentError: -12.3,
            interval: 0,
            tuningSystem: "equalTemperament"
        )

        try store.save(record)

        let fetched = try store.fetchAllPitchMatchings()

        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 69)
        #expect(fetched[0].targetNote == 69)
        #expect(fetched[0].initialCentOffset == 42.5)
        #expect(fetched[0].userCentError == -12.3)
    }

    @Test("FetchAllPitchMatching returns records in timestamp order")
    func fetchPitchMatchingInOrder() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let now = Date()
        let record1 = PitchMatchingRecord(referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament", timestamp: now.addingTimeInterval(-60))
        let record2 = PitchMatchingRecord(referenceNote: 64, targetNote: 64, initialCentOffset: 20.0, userCentError: -3.0, interval: 0, tuningSystem: "equalTemperament", timestamp: now.addingTimeInterval(-30))
        let record3 = PitchMatchingRecord(referenceNote: 72, targetNote: 72, initialCentOffset: 30.0, userCentError: 1.5, interval: 0, tuningSystem: "equalTemperament", timestamp: now)

        try store.save(record1)
        try store.save(record2)
        try store.save(record3)

        let fetched = try store.fetchAllPitchMatchings()

        #expect(fetched.count == 3)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[1].referenceNote == 64)
        #expect(fetched[2].referenceNote == 72)
    }

    @Test("FetchAllPitchMatching returns empty array when no records exist")
    func fetchPitchMatchingFromEmptyStore() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let fetched = try store.fetchAllPitchMatchings()

        #expect(fetched.isEmpty)
    }

    // MARK: - Delete All Tests

    @Test("DeleteAll removes both comparison and pitch matching records")
    func deleteAllRemovesBothTypes() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let comparisonRecord = ComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(comparisonRecord)

        let pitchRecord1 = PitchMatchingRecord(referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament")
        let pitchRecord2 = PitchMatchingRecord(referenceNote: 64, targetNote: 64, initialCentOffset: 20.0, userCentError: -3.0, interval: 0, tuningSystem: "equalTemperament")
        try store.save(pitchRecord1)
        try store.save(pitchRecord2)

        try store.deleteAll()

        let comparisonFetched = try store.fetchAllComparisons()
        #expect(comparisonFetched.isEmpty)

        let pitchFetched = try store.fetchAllPitchMatchings()
        #expect(pitchFetched.isEmpty)
    }

    // MARK: - PitchMatchingObserver Conformance Tests

    @Test("PitchMatchingObserver conformance saves record with all fields via observer")
    func pitchMatchingObserverSaves() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let completed = CompletedPitchMatching(
            referenceNote: 69,
            targetNote: 69,
            initialCentOffset: 42.5,
            userCentError: -12.3,
            tuningSystem: .equalTemperament,
            timestamp: timestamp
        )

        store.pitchMatchingCompleted(completed)

        let fetched = try store.fetchAllPitchMatchings()

        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 69)
        #expect(fetched[0].targetNote == 69)
        #expect(fetched[0].initialCentOffset == 42.5)
        #expect(fetched[0].userCentError == -12.3)
        #expect(fetched[0].interval == 0)
        #expect(fetched[0].tuningSystem == "equalTemperament")
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    @Test("PitchMatchingObserver saves multiple records from repeated calls")
    func pitchMatchingObserverSavesMultiple() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let completed = CompletedPitchMatching(
            referenceNote: 69,
            targetNote: 69,
            initialCentOffset: 42.5,
            userCentError: -12.3,
            tuningSystem: .equalTemperament
        )

        store.pitchMatchingCompleted(completed)
        store.pitchMatchingCompleted(completed)

        let fetched = try store.fetchAllPitchMatchings()
        #expect(fetched.count == 2)
    }

    // MARK: - ComparisonObserver Conformance Tests

    @Test("ComparisonObserver conformance saves record with derived interval and tuningSystem")
    func comparisonObserverSaves() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let timestamp = Date()
        let comparison = Comparison(
            referenceNote: 60,
            targetNote: DetunedMIDINote(note: 60, offset: Cents(25.0))
        )
        let completed = CompletedComparison(
            comparison: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament,
            timestamp: timestamp
        )

        store.comparisonCompleted(completed)

        let fetched = try store.fetchAllComparisons()

        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 60)
        #expect(fetched[0].centOffset == 25.0)
        #expect(fetched[0].isCorrect == true)
        #expect(fetched[0].interval == 0)
        #expect(fetched[0].tuningSystem == "equalTemperament")
        #expect(abs(fetched[0].timestamp.timeIntervalSince(timestamp)) < 0.001)
    }

    // MARK: - Pitch Matching Atomic Write Tests

    // MARK: - Interval Context Verification (Story 23.4)

    @Test("ComparisonObserver persists correct interval and tuningSystem for non-prime interval")
    func comparisonObserverWithInterval() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let comparison = Comparison(
            referenceNote: MIDINote(60),
            targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(25.0))
        )
        let completed = CompletedComparison(
            comparison: comparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )

        store.comparisonCompleted(completed)

        let fetched = try store.fetchAllComparisons()
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 67)
        #expect(fetched[0].interval == 7)
        #expect(fetched[0].tuningSystem == "equalTemperament")
        #expect(fetched[0].centOffset == 25.0)
    }

    @Test("PitchMatchingObserver persists correct interval and tuningSystem for non-prime interval")
    func pitchMatchingObserverWithInterval() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let completed = CompletedPitchMatching(
            referenceNote: MIDINote(60),
            targetNote: MIDINote(60).transposed(by: .perfectFifth),
            initialCentOffset: 30.0,
            userCentError: -5.0,
            tuningSystem: .equalTemperament
        )

        store.pitchMatchingCompleted(completed)

        let fetched = try store.fetchAllPitchMatchings()
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 67)
        #expect(fetched[0].interval == 7)
        #expect(fetched[0].tuningSystem == "equalTemperament")
        #expect(fetched[0].initialCentOffset == 30.0)
        #expect(fetched[0].userCentError == -5.0)
    }

    // MARK: - Pitch Matching Atomic Write Tests

    @Test("Pitch matching atomic write - successful save is complete")
    func pitchMatchingAtomicWriteSuccess() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = PitchMatchingRecord(referenceNote: 60, targetNote: 60, initialCentOffset: 10.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament")
        try store.save(record)

        let fetched = try store.fetchAllPitchMatchings()
        #expect(fetched.count == 1)
        #expect(fetched[0].referenceNote == 60)
        #expect(fetched[0].targetNote == 60)
        #expect(fetched[0].initialCentOffset == 10.0)
        #expect(fetched[0].userCentError == 5.0)
    }
}
