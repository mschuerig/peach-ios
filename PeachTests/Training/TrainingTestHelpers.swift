import Testing
@testable import Peach

// MARK: - Shared Async Test Helpers

/// Polls until the session reaches the expected state, or records a test failure on timeout.
@MainActor
func waitForState(_ session: TrainingSession, _ expectedState: TrainingState, timeout: Duration = .seconds(2)) async throws {
    await Task.yield()
    if session.state == expectedState { return }
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if session.state == expectedState { return }
        try await Task.sleep(for: .milliseconds(5))
        await Task.yield()
    }
    Issue.record("Timeout waiting for state \(expectedState), current state: \(session.state)")
}

/// Polls until the mock player's play call count reaches the minimum, or records a test failure on timeout.
@MainActor
func waitForPlayCallCount(_ mockPlayer: MockNotePlayer, _ minCount: Int, timeout: Duration = .seconds(2)) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if mockPlayer.playCallCount >= minCount { return }
        try await Task.sleep(for: .milliseconds(5))
        await Task.yield()
    }
    Issue.record("Timeout waiting for playCallCount >= \(minCount), current: \(mockPlayer.playCallCount)")
}

/// Polls until the session's showFeedback becomes false, or records a test failure on timeout.
@MainActor
func waitForFeedbackToClear(_ session: TrainingSession, timeout: Duration = .seconds(2)) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if !session.showFeedback { return }
        try await Task.sleep(for: .milliseconds(10))
        await Task.yield()
    }
    Issue.record("Timeout waiting for feedback to clear")
}
