import Testing
import Foundation
@testable import Peach

// MARK: - Shared Test Fixture

/// Holds all components of a training session test fixture.
struct TrainingSessionFixture {
    let session: TrainingSession
    let mockPlayer: MockNotePlayer
    let mockDataStore: MockTrainingDataStore
    let profile: PerceptualProfile
    let mockStrategy: MockNextNoteStrategy
    let mockHaptic: MockHapticFeedbackManager?
    let notificationCenter: NotificationCenter?
}

/// Shared factory for creating a TrainingSession with all mock dependencies.
@MainActor
func makeTrainingSession(
    comparisons: [Comparison] = [
        Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true),
        Comparison(note1: 62, note2: 62, centDifference: 95.0, isSecondNoteHigher: false)
    ],
    settingsOverride: TrainingSettings? = TrainingSettings(),
    noteDurationOverride: TimeInterval? = 1.0,
    includeHaptic: Bool = false,
    notificationCenter: NotificationCenter? = nil
) -> TrainingSessionFixture {
    let mockPlayer = MockNotePlayer()
    let mockDataStore = MockTrainingDataStore()
    let profile = PerceptualProfile()
    let mockStrategy = MockNextNoteStrategy(comparisons: comparisons)

    var observers: [ComparisonObserver] = [mockDataStore, profile]
    let mockHaptic: MockHapticFeedbackManager?
    if includeHaptic {
        let haptic = MockHapticFeedbackManager()
        observers.append(haptic)
        mockHaptic = haptic
    } else {
        mockHaptic = nil
    }

    let session = TrainingSession(
        notePlayer: mockPlayer,
        strategy: mockStrategy,
        profile: profile,
        settingsOverride: settingsOverride,
        noteDurationOverride: noteDurationOverride,
        observers: observers,
        notificationCenter: notificationCenter ?? .default
    )

    return TrainingSessionFixture(
        session: session,
        mockPlayer: mockPlayer,
        mockDataStore: mockDataStore,
        profile: profile,
        mockStrategy: mockStrategy,
        mockHaptic: mockHaptic,
        notificationCenter: notificationCenter
    )
}

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
