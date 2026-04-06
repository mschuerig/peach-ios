import Foundation
@testable import Peach

final class MockTimingOffsetDetectionObserver: TimingOffsetDetectionObserver {
    // MARK: - Test State Tracking

    var completedCallCount = 0
    var lastResult: CompletedTimingOffsetDetectionTrial?
    var results: [CompletedTimingOffsetDetectionTrial] = []

    // MARK: - TimingOffsetDetectionObserver Protocol

    func timingOffsetDetectionCompleted(_ result: CompletedTimingOffsetDetectionTrial) {
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
