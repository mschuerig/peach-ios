import Testing
import SwiftData
import Foundation
@testable import Peach

/// Edge case and error handling tests for TrainingDataStore
@Suite("TrainingDataStore Edge Case Tests")
struct TrainingDataStoreEdgeCaseTests {

    // MARK: - Test Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: PitchDiscriminationRecord.self, PitchMatchingRecord.self, TimingOffsetDetectionRecord.self, ContinuousRhythmMatchingRecord.self, configurations: config)
    }

    // MARK: - Edge Case Tests

    @Test("Save multiple records with identical data")
    func saveDuplicateData() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record1 = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 50.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        let record2 = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 50.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")

        try store.save(record1)
        try store.save(record2)

        let fetched = try store.fetchAllPitchDiscriminations()
        #expect(fetched.count == 2)
    }

    @Test("MIDI note boundaries are stored correctly")
    func midiNoteBoundaries() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let minRecord = PitchDiscriminationRecord(referenceNote: 0, targetNote: 0, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        let maxRecord = PitchDiscriminationRecord(referenceNote: 127, targetNote: 127, centOffset: 20.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament")

        try store.save(minRecord)
        try store.save(maxRecord)

        let fetched = try store.fetchAllPitchDiscriminations()
        #expect(fetched.count == 2)
        #expect(fetched.contains { $0.referenceNote == 0 })
        #expect(fetched.contains { $0.referenceNote == 127 })
    }

    @Test("Fractional cent offsets are stored with precision")
    func fractionalCentPrecision() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = PitchDiscriminationRecord(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 12.3,
            isCorrect: true,
            interval: 0,
            tuningSystem: "equalTemperament"
        )

        try store.save(record)

        let fetched = try store.fetchAllPitchDiscriminations()
        #expect(fetched.count == 1)
        #expect(fetched[0].centOffset == 12.3)
    }

    // MARK: - Error Handling Tests

    @Test("FetchAll throws DataStoreError.fetchFailed when context is invalid")
    func fetchAllThrowsOnInvalidContext() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(record)

        do {
            _ = try store.fetchAllPitchDiscriminations()
        } catch let error as Peach.DataStoreError {
            switch error {
            case .fetchFailed(let message):
                #expect(message.contains("Failed to fetch"))
            default:
                Issue.record("Expected fetchFailed error")
            }
        }
    }

    @Test("Save throws DataStoreError.saveFailed on context save failure")
    func saveThrowsOnContextFailure() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")

        do {
            try store.save(record)
        } catch let error as Peach.DataStoreError {
            switch error {
            case .saveFailed(let message):
                #expect(message.contains("Failed to save"))
            default:
                Issue.record("Expected saveFailed error")
            }
        }
    }

    @Test("Delete throws DataStoreError.deleteFailed on context save failure")
    func deleteThrowsOnContextFailure() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(record)

        do {
            try store.delete(record)
        } catch let error as Peach.DataStoreError {
            switch error {
            case .deleteFailed(let message):
                #expect(message.contains("Failed to delete"))
            default:
                Issue.record("Expected deleteFailed error")
            }
        }
    }

    // MARK: - Atomic Replace Tests

    @Test("replaceAllRecords inserts new records after deleting existing ones")
    func replaceAllRecordsInsertsAfterDelete() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let existing = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        try store.save(existing)

        let newComparison = PitchDiscriminationRecord(referenceNote: 72, targetNote: 72, centOffset: 20.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament")
        let newMatching = PitchMatchingRecord(referenceNote: 69, targetNote: 69, initialCentOffset: 30.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament")

        var records: [any PersistentModel] = [newComparison, newMatching]
        try store.replaceAllRecords(records)

        let comparisons = try store.fetchAllPitchDiscriminations()
        let matchings = try store.fetchAllPitchMatchings()

        #expect(comparisons.count == 1)
        #expect(comparisons[0].referenceNote == 72)
        #expect(matchings.count == 1)
        #expect(matchings[0].referenceNote == 69)
    }

    @Test("replaceAllRecords with empty arrays clears all data")
    func replaceAllRecordsWithEmptyArrays() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let comparison = PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        let matching = PitchMatchingRecord(referenceNote: 69, targetNote: 69, initialCentOffset: 30.0, userCentError: 5.0, interval: 0, tuningSystem: "equalTemperament")
        try store.save(comparison)
        try store.save(matching)

        try store.replaceAllRecords([])

        let comparisons = try store.fetchAllPitchDiscriminations()
        let matchings = try store.fetchAllPitchMatchings()

        #expect(comparisons.isEmpty)
        #expect(matchings.isEmpty)
    }

    @Test("replaceAllRecords handles multiple records of both types")
    func replaceAllRecordsMultiple() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let comparisons = (0..<5).map { i in
            PitchDiscriminationRecord(referenceNote: 60 + i, targetNote: 60 + i, centOffset: Double(i) * 10, isCorrect: true, interval: 0, tuningSystem: "equalTemperament")
        }
        let matchings = (0..<3).map { i in
            PitchMatchingRecord(referenceNote: 69 + i, targetNote: 69 + i, initialCentOffset: Double(i) * 15, userCentError: Double(i), interval: 0, tuningSystem: "equalTemperament")
        }

        var records: [any PersistentModel] = comparisons + matchings
        try store.replaceAllRecords(records)

        let fetchedComparisons = try store.fetchAllPitchDiscriminations()
        let fetchedMatchings = try store.fetchAllPitchMatchings()

        #expect(fetchedComparisons.count == 5)
        #expect(fetchedMatchings.count == 3)
    }

    @Test("DataStoreError cases have descriptive messages")
    func dataStoreErrorMessages() async {
        let saveError = Peach.DataStoreError.saveFailed("Test save error")
        let fetchError = Peach.DataStoreError.fetchFailed("Test fetch error")
        let deleteError = Peach.DataStoreError.deleteFailed("Test delete error")
        let contextError = Peach.DataStoreError.contextUnavailable

        switch saveError {
        case .saveFailed(let message):
            #expect(message == "Test save error")
        default:
            Issue.record("saveFailed case not matched")
        }

        switch fetchError {
        case .fetchFailed(let message):
            #expect(message == "Test fetch error")
        default:
            Issue.record("fetchFailed case not matched")
        }

        switch deleteError {
        case .deleteFailed(let message):
            #expect(message == "Test delete error")
        default:
            Issue.record("deleteFailed case not matched")
        }

        switch contextError {
        case .contextUnavailable:
            break
        default:
            Issue.record("contextUnavailable case not matched")
        }
    }
}
