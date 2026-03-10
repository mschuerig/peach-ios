import Testing
import Foundation
@testable import Peach

// MARK: - Default Test Settings

let defaultTestSettings = PitchComparisonTrainingSettings(
    referencePitch: Frequency(440.0),
    intervals: [.prime],
    noteDuration: NoteDuration(1.0)
)

// MARK: - Shared Test Fixture

struct PitchComparisonSessionFixture {
    let session: PitchComparisonSession
    let mockPlayer: MockNotePlayer
    let mockDataStore: MockTrainingDataStore
    let profile: PerceptualProfile
    let mockStrategy: MockNextPitchComparisonStrategy
    let mockHaptic: MockHapticFeedbackManager?
    let notificationCenter: NotificationCenter?
}

func makePitchComparisonSession(
    comparisons: [PitchComparison] = [
        PitchComparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0))),
        PitchComparison(referenceNote: 62, targetNote: DetunedMIDINote(note: 62, offset: Cents(-95.0)))
    ],
    resettables: [Resettable] = [],
    includeHaptic: Bool = false,
    notificationCenter: NotificationCenter? = nil
) -> PitchComparisonSessionFixture {
    let mockPlayer = MockNotePlayer()
    let mockDataStore = MockTrainingDataStore()
    let profile = PerceptualProfile()
    let mockStrategy = MockNextPitchComparisonStrategy(comparisons: comparisons)

    var observers: [PitchComparisonObserver] = [mockDataStore, profile]
    let mockHaptic: MockHapticFeedbackManager?
    if includeHaptic {
        let haptic = MockHapticFeedbackManager()
        observers.append(haptic)
        mockHaptic = haptic
    } else {
        mockHaptic = nil
    }

    let session = PitchComparisonSession(
        notePlayer: mockPlayer,
        strategy: mockStrategy,
        profile: profile,
        resettables: resettables,
        observers: observers,
        notificationCenter: notificationCenter ?? .default
    )

    return PitchComparisonSessionFixture(
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

func waitForState(_ session: PitchComparisonSession, _ expectedState: PitchComparisonSessionState, timeout: Duration = .seconds(2)) async throws {
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

func waitForFeedbackToClear(_ session: PitchComparisonSession, timeout: Duration = .seconds(2)) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if !session.showFeedback { return }
        try await Task.sleep(for: .milliseconds(10))
        await Task.yield()
    }
    Issue.record("Timeout waiting for feedback to clear")
}
