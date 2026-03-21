import Foundation
@testable import Peach

final class MockRhythmOffsetDetectionObserver: RhythmOffsetDetectionObserver {
    // MARK: - Test State Tracking

    var completedCallCount = 0
    var lastResult: CompletedRhythmOffsetDetectionTrial?
    var results: [CompletedRhythmOffsetDetectionTrial] = []

    // MARK: - RhythmOffsetDetectionObserver Protocol

    func rhythmOffsetDetectionCompleted(_ result: CompletedRhythmOffsetDetectionTrial) {
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
