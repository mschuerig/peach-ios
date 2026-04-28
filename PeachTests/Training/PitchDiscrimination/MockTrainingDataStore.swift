import Foundation
@testable import Peach

final class MockTrainingDataStore: TrainingRecordPersisting, PitchDiscriminationObserver, PitchMatchingObserver {
    // MARK: - Comparison Test State Tracking

    var saveCallCount = 0
    var lastSavedRecord: PitchDiscriminationPayload?
    var savedRecords: [PitchDiscriminationPayload] = []
    var shouldThrowError = false
    var errorToThrow: DataStoreError = .saveFailed("Mock error")

    // MARK: - Observer Domain Object Tracking

    var completedTrials: [CompletedPitchDiscriminationTrial] = []
    var completedPitchMatchings: [CompletedPitchMatchingTrial] = []

    // MARK: - Pitch Matching Test State Tracking

    var savePitchMatchingCallCount = 0
    var lastSavedPitchMatchingRecord: PitchMatchingPayload?
    var savedPitchMatchingRecords: [PitchMatchingPayload] = []

    // MARK: - Test Control

    var onSaveCalled: (() -> Void)?
    var onSavePitchMatchingCalled: (() -> Void)?
    var onFetchCalled: (() -> Void)?
    var onPitchDiscriminationCompletedCalled: (() -> Void)?
    var onPitchMatchingCompletedCalled: (() -> Void)?

    // MARK: - TrainingRecordPersisting

    func save(_ envelope: TrainingRecord) throws {
        if shouldThrowError {
            throw errorToThrow
        }

        switch envelope.disciplineIdentifier {
        case PitchDiscriminationPayload.disciplineIdentifier:
            let payload = try JSONEnvelope.decode(PitchDiscriminationPayload.self, from: envelope)
            saveCallCount += 1
            lastSavedRecord = payload
            savedRecords.append(payload)
            onSaveCalled?()
        case PitchMatchingPayload.disciplineIdentifier:
            let payload = try JSONEnvelope.decode(PitchMatchingPayload.self, from: envelope)
            savePitchMatchingCallCount += 1
            lastSavedPitchMatchingRecord = payload
            savedPitchMatchingRecords.append(payload)
            onSavePitchMatchingCalled?()
        default:
            fatalError("MockTrainingDataStore: unhandled discipline \(envelope.disciplineIdentifier)")
        }
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
        // Forward via the adapter so save() is exercised consistently with prod.
        PitchDiscriminationStoreAdapter(store: self).pitchDiscriminationCompleted(completed)
    }

    // MARK: - PitchMatchingObserver Protocol

    func pitchMatchingCompleted(_ result: CompletedPitchMatchingTrial) {
        onPitchMatchingCompletedCalled?()
        completedPitchMatchings.append(result)
        PitchMatchingStoreAdapter(store: self).pitchMatchingCompleted(result)
    }
}
