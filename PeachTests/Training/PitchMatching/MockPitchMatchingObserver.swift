@testable import Peach

final class MockPitchMatchingObserver: PitchMatchingObserver {
    // MARK: - Test State Tracking

    var pitchMatchingCompletedCallCount = 0
    var lastResult: CompletedPitchMatchingTrial?
    var resultHistory: [CompletedPitchMatchingTrial] = []

    // MARK: - Test Control

    var onPitchMatchingCompletedCalled: (() -> Void)?

    // MARK: - PitchMatchingObserver Protocol

    func pitchMatchingCompleted(_ result: CompletedPitchMatchingTrial) {
        pitchMatchingCompletedCallCount += 1
        lastResult = result
        resultHistory.append(result)
        onPitchMatchingCompletedCalled?()
    }

    // MARK: - Test Helpers

    func reset() {
        pitchMatchingCompletedCallCount = 0
        lastResult = nil
        resultHistory = []
        onPitchMatchingCompletedCalled = nil
    }
}
