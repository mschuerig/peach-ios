import Foundation
@testable import Peach

final class MockContinuousRhythmMatchingObserver: ContinuousRhythmMatchingObserver {
    // MARK: - Test State Tracking

    var completedCallCount = 0
    var lastResult: CompletedContinuousRhythmMatchingTrial?
    var results: [CompletedContinuousRhythmMatchingTrial] = []

    // MARK: - Callbacks

    var onCompleted: (() -> Void)?

    // MARK: - Continuation-Based Wait

    private var completionWaiters: [(minCount: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func waitForCompletion(minCount: Int = 1) async {
        if completedCallCount >= minCount { return }
        await withCheckedContinuation { continuation in
            completionWaiters.append((minCount: minCount, continuation: continuation))
        }
    }

    // MARK: - ContinuousRhythmMatchingObserver Protocol

    func continuousRhythmMatchingCompleted(_ result: CompletedContinuousRhythmMatchingTrial) {
        completedCallCount += 1
        lastResult = result
        results.append(result)

        onCompleted?()

        let satisfied = completionWaiters.filter { completedCallCount >= $0.minCount }
        completionWaiters.removeAll { completedCallCount >= $0.minCount }
        for entry in satisfied {
            entry.continuation.resume()
        }
    }

    // MARK: - Test Helpers

    func reset() {
        completedCallCount = 0
        lastResult = nil
        results = []
        onCompleted = nil
        completionWaiters.removeAll()
    }
}
