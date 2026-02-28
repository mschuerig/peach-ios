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
        return try ModelContainer(for: ComparisonRecord.self, PitchMatchingRecord.self, configurations: config)
    }

    // MARK: - Edge Case Tests

    @Test("Save multiple records with identical data")
    func saveDuplicateData() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record1 = ComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 50.0, isCorrect: true)
        let record2 = ComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 50.0, isCorrect: true)

        try store.save(record1)
        try store.save(record2)

        let fetched = try store.fetchAllComparisons()
        #expect(fetched.count == 2)
    }

    @Test("MIDI note boundaries are stored correctly")
    func midiNoteBoundaries() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let minRecord = ComparisonRecord(referenceNote: 0, targetNote: 0, centOffset: 10.0, isCorrect: true)
        let maxRecord = ComparisonRecord(referenceNote: 127, targetNote: 127, centOffset: 20.0, isCorrect: false)

        try store.save(minRecord)
        try store.save(maxRecord)

        let fetched = try store.fetchAllComparisons()
        #expect(fetched.count == 2)
        #expect(fetched.contains { $0.referenceNote == 0 })
        #expect(fetched.contains { $0.referenceNote == 127 })
    }

    @Test("Fractional cent offsets are stored with precision")
    func fractionalCentPrecision() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = ComparisonRecord(
            referenceNote: 60,
            targetNote: 60,
            centOffset: 12.3,
            isCorrect: true
        )

        try store.save(record)

        let fetched = try store.fetchAllComparisons()
        #expect(fetched.count == 1)
        #expect(fetched[0].centOffset == 12.3)
    }

    // MARK: - Error Handling Tests

    @Test("FetchAll throws DataStoreError.fetchFailed when context is invalid")
    func fetchAllThrowsOnInvalidContext() async throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let store = TrainingDataStore(modelContext: context)

        let record = ComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true)
        try store.save(record)

        do {
            _ = try store.fetchAllComparisons()
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

        let record = ComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true)

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

        let record = ComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 10.0, isCorrect: true)
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

    @Test("DataStoreError cases have descriptive messages")
    func dataStoreErrorMessages() {
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
