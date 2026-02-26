@testable import Peach

final class MockPitchMatchingObserver: PitchMatchingObserver {
    var pitchMatchingCompletedCallCount = 0
    var lastResult: CompletedPitchMatching?
    var resultHistory: [CompletedPitchMatching] = []

    func pitchMatchingCompleted(_ result: CompletedPitchMatching) {
        pitchMatchingCompletedCallCount += 1
        lastResult = result
        resultHistory.append(result)
    }

    func reset() {
        pitchMatchingCompletedCallCount = 0
        lastResult = nil
        resultHistory = []
    }
}
