import Foundation
@testable import Peach

final class MockRhythmMatchingObserver: RhythmMatchingObserver {
    // MARK: - Test State Tracking

    var completedCallCount = 0
    var lastResult: CompletedRhythmMatchingTrial?
    var results: [CompletedRhythmMatchingTrial] = []

    // MARK: - RhythmMatchingObserver Protocol

    func rhythmMatchingCompleted(_ result: CompletedRhythmMatchingTrial) {
        completedCallCount += 1
        lastResult = result
        results.append(result)
    }

    // MARK: - Test Helpers

    func reset() {
        completedCallCount = 0
        lastResult = nil
        results = []
    }
}
