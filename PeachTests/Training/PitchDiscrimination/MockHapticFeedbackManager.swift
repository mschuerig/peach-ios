import Foundation
@testable import Peach

/// Mock haptic feedback manager for unit tests
final class MockHapticFeedbackManager: HapticFeedback, PitchDiscriminationObserver, TimingOffsetDetectionObserver {

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

    // MARK: - TimingOffsetDetectionObserver

    private(set) var timingOffsetDetectionCompletedCallCount = 0
    var lastTimingOffsetDetection: CompletedTimingOffsetDetectionTrial?

    func timingOffsetDetectionCompleted(_ result: CompletedTimingOffsetDetectionTrial) {
        timingOffsetDetectionCompletedCallCount += 1
        lastTimingOffsetDetection = result
        onTimingOffsetDetectionCompletedCalled?()
    }

    // MARK: - Test Control

    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "MockHapticFeedback", code: 1)
    var onPlayIncorrectFeedbackCalled: (() -> Void)?
    var onPitchDiscriminationCompletedCalled: (() -> Void)?
    var onTimingOffsetDetectionCompletedCalled: (() -> Void)?

    // MARK: - Test Helpers

    func reset() {
        incorrectFeedbackCount = 0
        pitchDiscriminationCompletedCallCount = 0
        lastTrial = nil
        timingOffsetDetectionCompletedCallCount = 0
        lastTimingOffsetDetection = nil
        shouldThrowError = false
        onPlayIncorrectFeedbackCalled = nil
        onPitchDiscriminationCompletedCalled = nil
        onTimingOffsetDetectionCompletedCalled = nil
    }
}
