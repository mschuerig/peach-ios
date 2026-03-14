@testable import Peach

final class MockPitchMatchingProfile: PitchMatchingProfile {
    // MARK: - Test State Tracking

    var updateMatchingCallCount = 0
    var lastNote: Int?
    var lastCentError: Cents?
    var matchingMean: Cents? = nil
    var matchingStdDev: Cents? = nil
    var matchingSampleCount: Int = 0
    // MARK: - Test Control

    var onUpdateMatchingCalled: (() -> Void)?

    // MARK: - PitchMatchingProfile Protocol

    func updateMatching(note: MIDINote, centError: Cents) {
        updateMatchingCallCount += 1
        lastNote = note.rawValue
        lastCentError = centError
        onUpdateMatchingCalled?()
    }

    // MARK: - Test Helpers

    func reset() {
        updateMatchingCallCount = 0
        lastNote = nil
        lastCentError = nil
        matchingMean = nil
        matchingStdDev = nil
        matchingSampleCount = 0
        onUpdateMatchingCalled = nil
    }
}
