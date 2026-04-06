import Foundation
@testable import Peach

final class MockTrainingDataStore: PitchDiscriminationRecordStoring, PitchDiscriminationObserver, PitchMatchingObserver {
    // MARK: - Comparison Test State Tracking

    var saveCallCount = 0
    var lastSavedRecord: PitchDiscriminationRecord?
    var savedRecords: [PitchDiscriminationRecord] = []
    var shouldThrowError = false
    var errorToThrow: DataStoreError = .saveFailed("Mock error")

    // MARK: - Observer Domain Object Tracking

    var completedTrials: [CompletedPitchDiscriminationTrial] = []
    var completedPitchMatchings: [CompletedPitchMatchingTrial] = []

    // MARK: - Pitch Matching Test State Tracking

    var savePitchMatchingCallCount = 0
    var lastSavedPitchMatchingRecord: PitchMatchingRecord?
    var savedPitchMatchingRecords: [PitchMatchingRecord] = []

    // MARK: - Test Control

    var onSaveCalled: (() -> Void)?
    var onSavePitchMatchingCalled: (() -> Void)?
    var onFetchCalled: (() -> Void)?
    var onPitchDiscriminationCompletedCalled: (() -> Void)?
    var onPitchMatchingCompletedCalled: (() -> Void)?

    // MARK: - PitchDiscriminationRecordStoring Protocol

    func save(_ record: PitchDiscriminationRecord) throws {
        saveCallCount += 1
        lastSavedRecord = record

        onSaveCalled?()

        if shouldThrowError {
            throw errorToThrow
        }

        savedRecords.append(record)
    }

    func fetchAllPitchDiscriminations() throws -> [PitchDiscriminationRecord] {
        onFetchCalled?()

        if shouldThrowError {
            throw DataStoreError.fetchFailed("Mock error")
        }
        return savedRecords
    }

    // MARK: - Pitch Matching Methods

    func save(_ record: PitchMatchingRecord) throws {
        savePitchMatchingCallCount += 1
        lastSavedPitchMatchingRecord = record

        onSavePitchMatchingCalled?()

        if shouldThrowError {
            throw errorToThrow
        }

        savedPitchMatchingRecords.append(record)
    }

    func fetchAllPitchMatchings() throws -> [PitchMatchingRecord] {
        onFetchCalled?()

        if shouldThrowError {
            throw DataStoreError.fetchFailed("Mock error")
        }
        return savedPitchMatchingRecords
    }

    // MARK: - Test Helpers

    func reset() {
        saveCallCount = 0
        lastSavedRecord = nil
        savedRecords = []
        completedTrials = []
        completedPitchMatchings = []
        savePitchMatchingCallCount = 0
        lastSavedPitchMatchingRecord = nil
        savedPitchMatchingRecords = []
        shouldThrowError = false
        onSaveCalled = nil
        onSavePitchMatchingCalled = nil
        onFetchCalled = nil
        onPitchDiscriminationCompletedCalled = nil
        onPitchMatchingCompletedCalled = nil
    }

    // MARK: - PitchDiscriminationObserver Protocol

    func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial) {
        onPitchDiscriminationCompletedCalled?()
        completedTrials.append(completed)
        // Create record for backward compatibility with tests that check savedRecords
        let trial = completed.trial
        let record = PitchDiscriminationRecord(
            referenceNote: trial.referenceNote.rawValue,
            targetNote: trial.targetNote.note.rawValue,
            centOffset: trial.targetNote.offset.rawValue,
            isCorrect: completed.isCorrect,
            interval: 0,
            tuningSystem: "equalTemperament",
            timestamp: completed.timestamp
        )
        try? save(record)
    }

    // MARK: - PitchMatchingObserver Protocol

    func pitchMatchingCompleted(_ result: CompletedPitchMatchingTrial) {
        onPitchMatchingCompletedCalled?()
        completedPitchMatchings.append(result)
        // Create record for backward compatibility with tests that check savedPitchMatchingRecords
        let record = PitchMatchingRecord(
            referenceNote: result.referenceNote.rawValue,
            targetNote: result.targetNote.rawValue,
            initialCentOffset: result.initialCentOffset.rawValue,
            userCentError: result.userCentError.rawValue,
            interval: 0,
            tuningSystem: "equalTemperament",
            timestamp: result.timestamp
        )
        try? save(record)
    }
}
