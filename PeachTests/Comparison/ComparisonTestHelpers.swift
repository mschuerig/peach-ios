import Testing
import Foundation
@testable import Peach

// MARK: - Shared Test Fixture

struct ComparisonSessionFixture {
    let session: ComparisonSession
    let mockPlayer: MockNotePlayer
    let mockDataStore: MockTrainingDataStore
    let profile: PerceptualProfile
    let mockStrategy: MockNextComparisonStrategy
    let mockHaptic: MockHapticFeedbackManager?
    let notificationCenter: NotificationCenter?
    let mockSettings: MockUserSettings
}

func makeComparisonSession(
    comparisons: [Comparison] = [
        Comparison(note1: 60, note2: 60, centDifference: Cents(100.0)),
        Comparison(note1: 62, note2: 62, centDifference: Cents(-95.0))
    ],
    userSettings: MockUserSettings = MockUserSettings(),
    resettables: [Resettable] = [],
    includeHaptic: Bool = false,
    notificationCenter: NotificationCenter? = nil
) -> ComparisonSessionFixture {
    let mockPlayer = MockNotePlayer()
    let mockDataStore = MockTrainingDataStore()
    let profile = PerceptualProfile()
    let mockStrategy = MockNextComparisonStrategy(comparisons: comparisons)

    var observers: [ComparisonObserver] = [mockDataStore, profile]
    let mockHaptic: MockHapticFeedbackManager?
    if includeHaptic {
        let haptic = MockHapticFeedbackManager()
        observers.append(haptic)
        mockHaptic = haptic
    } else {
        mockHaptic = nil
    }

    let session = ComparisonSession(
        notePlayer: mockPlayer,
        strategy: mockStrategy,
        profile: profile,
        userSettings: userSettings,
        resettables: resettables,
        observers: observers,
        notificationCenter: notificationCenter ?? .default
    )

    return ComparisonSessionFixture(
        session: session,
        mockPlayer: mockPlayer,
        mockDataStore: mockDataStore,
        profile: profile,
        mockStrategy: mockStrategy,
        mockHaptic: mockHaptic,
        notificationCenter: notificationCenter,
        mockSettings: userSettings
    )
}

// MARK: - Shared Async Test Helpers

func waitForState(_ session: ComparisonSession, _ expectedState: ComparisonSessionState, timeout: Duration = .seconds(2)) async throws {
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

func waitForPlayCallCount(_ mockPlayer: MockNotePlayer, _ minCount: Int, timeout: Duration = .seconds(2)) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if mockPlayer.playCallCount >= minCount { return }
        try await Task.sleep(for: .milliseconds(5))
        await Task.yield()
    }
    Issue.record("Timeout waiting for playCallCount >= \(minCount), current: \(mockPlayer.playCallCount)")
}

func waitForFeedbackToClear(_ session: ComparisonSession, timeout: Duration = .seconds(2)) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if !session.showFeedback { return }
        try await Task.sleep(for: .milliseconds(10))
        await Task.yield()
    }
    Issue.record("Timeout waiting for feedback to clear")
}
