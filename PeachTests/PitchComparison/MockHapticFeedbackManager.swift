import Foundation
@testable import Peach

/// Mock haptic feedback manager for unit tests
final class MockHapticFeedbackManager: HapticFeedback, PitchComparisonObserver, RhythmComparisonObserver {

    // MARK: - HapticFeedback

    private(set) var incorrectFeedbackCount = 0

    func playIncorrectFeedback() {
        incorrectFeedbackCount += 1
        onPlayIncorrectFeedbackCalled?()
    }

    // MARK: - PitchComparisonObserver

    private(set) var pitchComparisonCompletedCallCount = 0
    var lastPitchComparison: CompletedPitchComparison?

    func pitchComparisonCompleted(_ completed: CompletedPitchComparison) {
        pitchComparisonCompletedCallCount += 1
        lastPitchComparison = completed
        onPitchComparisonCompletedCalled?()
    }

    // MARK: - RhythmComparisonObserver

    private(set) var rhythmComparisonCompletedCallCount = 0
    var lastRhythmComparison: CompletedRhythmComparison?

    func rhythmComparisonCompleted(_ result: CompletedRhythmComparison) {
        rhythmComparisonCompletedCallCount += 1
        lastRhythmComparison = result
        onRhythmComparisonCompletedCalled?()
    }

    // MARK: - Test Control

    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "MockHapticFeedback", code: 1)
    var onPlayIncorrectFeedbackCalled: (() -> Void)?
    var onPitchComparisonCompletedCalled: (() -> Void)?
    var onRhythmComparisonCompletedCalled: (() -> Void)?

    // MARK: - Test Helpers

    func reset() {
        incorrectFeedbackCount = 0
        pitchComparisonCompletedCallCount = 0
        lastPitchComparison = nil
        rhythmComparisonCompletedCallCount = 0
        lastRhythmComparison = nil
        shouldThrowError = false
        onPlayIncorrectFeedbackCalled = nil
        onPitchComparisonCompletedCalled = nil
        onRhythmComparisonCompletedCalled = nil
    }
}
