@testable import Peach

/// Mock haptic feedback manager for unit tests
final class MockHapticFeedbackManager: HapticFeedback, ComparisonObserver {

    // MARK: - HapticFeedback

    private(set) var incorrectFeedbackCount = 0
    var onPlayIncorrectFeedbackCalled: (() -> Void)?

    func playIncorrectFeedback() {
        incorrectFeedbackCount += 1
        onPlayIncorrectFeedbackCalled?()
    }

    // MARK: - ComparisonObserver

    private(set) var comparisonCompletedCallCount = 0
    var lastComparison: CompletedComparison?

    func comparisonCompleted(_ completed: CompletedComparison) {
        comparisonCompletedCallCount += 1
        lastComparison = completed
    }

    // MARK: - Test Helpers

    func reset() {
        incorrectFeedbackCount = 0
        onPlayIncorrectFeedbackCalled = nil
        comparisonCompletedCallCount = 0
        lastComparison = nil
    }
}
