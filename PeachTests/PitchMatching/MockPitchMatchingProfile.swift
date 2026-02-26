@testable import Peach

final class MockPitchMatchingProfile: PitchMatchingProfile {
    var updateMatchingCallCount = 0
    var lastNote: Int?
    var lastCentError: Double?
    var matchingMean: Double? = nil
    var matchingStdDev: Double? = nil
    var matchingSampleCount: Int = 0
    var resetMatchingCallCount = 0

    func updateMatching(note: MIDINote, centError: Double) {
        updateMatchingCallCount += 1
        lastNote = note.rawValue
        lastCentError = centError
    }

    func resetMatching() {
        resetMatchingCallCount += 1
        matchingMean = nil
        matchingStdDev = nil
        matchingSampleCount = 0
    }

    func reset() {
        updateMatchingCallCount = 0
        lastNote = nil
        lastCentError = nil
        matchingMean = nil
        matchingStdDev = nil
        matchingSampleCount = 0
        resetMatchingCallCount = 0
    }
}
