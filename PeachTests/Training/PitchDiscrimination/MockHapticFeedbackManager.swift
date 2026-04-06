import Foundation
@testable import Peach

/// Mock haptic feedback manager for unit tests
final class MockHapticFeedbackManager: HapticFeedback, PitchDiscriminationObserver, RhythmOffsetDetectionObserver {

    // MARK: - HapticFeedback

    private(set) var incorrectFeedbackCount = 0

    func playIncorrectFeedback() {
        incorrectFeedbackCount += 1
        onPlayIncorrectFeedbackCalled?()
    }

    // MARK: - PitchDiscriminationObserver

    private(set) var pitchDiscriminationCompletedCallCount = 0
    var lastTrial: CompletedPitchDiscriminationTrial?

    func pitchDiscriminationCompleted(_ completed: CompletedPitchDiscriminationTrial) {
        pitchDiscriminationCompletedCallCount += 1
        lastTrial = completed
        onPitchDiscriminationCompletedCalled?()
    }

    // MARK: - RhythmOffsetDetectionObserver

    private(set) var rhythmOffsetDetectionCompletedCallCount = 0
    var lastRhythmOffsetDetection: CompletedRhythmOffsetDetectionTrial?

    func rhythmOffsetDetectionCompleted(_ result: CompletedRhythmOffsetDetectionTrial) {
        rhythmOffsetDetectionCompletedCallCount += 1
        lastRhythmOffsetDetection = result
        onRhythmOffsetDetectionCompletedCalled?()
    }

    // MARK: - Test Control

    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "MockHapticFeedback", code: 1)
    var onPlayIncorrectFeedbackCalled: (() -> Void)?
    var onPitchDiscriminationCompletedCalled: (() -> Void)?
    var onRhythmOffsetDetectionCompletedCalled: (() -> Void)?

    // MARK: - Test Helpers

    func reset() {
        incorrectFeedbackCount = 0
        pitchDiscriminationCompletedCallCount = 0
        lastTrial = nil
        rhythmOffsetDetectionCompletedCallCount = 0
        lastRhythmOffsetDetection = nil
        shouldThrowError = false
        onPlayIncorrectFeedbackCalled = nil
        onPitchDiscriminationCompletedCalled = nil
        onRhythmOffsetDetectionCompletedCalled = nil
    }
}
