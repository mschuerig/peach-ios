import Testing
import Foundation
@testable import Peach

// MARK: - Default Test Settings

let defaultTestSettings = PitchDiscriminationSettings(
    referencePitch: Frequency(440.0),
    intervals: [.prime],
    noteDuration: NoteDuration(1.0)
)

// MARK: - Shared Test Fixture

struct PitchDiscriminationSessionFixture {
    let session: PitchDiscriminationSession
    let mockPlayer: MockNotePlayer
    let mockDataStore: MockTrainingDataStore
    let profile: PerceptualProfile
    let mockStrategy: MockNextPitchDiscriminationStrategy
    let mockHaptic: MockHapticFeedbackManager?
    let notificationCenter: NotificationCenter?
}

func makePitchDiscriminationSession(
    comparisons: [PitchDiscriminationTrial] = [
        PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0))),
        PitchDiscriminationTrial(referenceNote: 62, targetNote: DetunedMIDINote(note: 62, offset: Cents(-95.0)))
    ],
    resettables: [Resettable] = [],
    includeHaptic: Bool = false,
    notificationCenter: NotificationCenter? = nil
) -> PitchDiscriminationSessionFixture {
    let mockPlayer = MockNotePlayer()
    let mockDataStore = MockTrainingDataStore()
    let profile = PerceptualProfile()
    let mockStrategy = MockNextPitchDiscriminationStrategy(comparisons: comparisons)

    var observers: [PitchDiscriminationObserver] = [mockDataStore, profile]
    let mockHaptic: MockHapticFeedbackManager?
    if includeHaptic {
        let haptic = MockHapticFeedbackManager()
        observers.append(haptic)
        mockHaptic = haptic
    } else {
        mockHaptic = nil
    }

    let session = PitchDiscriminationSession(
        notePlayer: mockPlayer,
        strategy: mockStrategy,
        profile: profile,
        resettables: resettables,
        observers: observers,
        notificationCenter: notificationCenter ?? .default
    )

    return PitchDiscriminationSessionFixture(
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

func waitForState(_ session: PitchDiscriminationSession, _ expectedState: PitchDiscriminationSessionState, timeout: Duration = .seconds(2)) async throws {
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


func waitForFeedbackToClear(_ session: PitchDiscriminationSession, timeout: Duration = .seconds(2)) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if !session.showFeedback { return }
        try await Task.sleep(for: .milliseconds(10))
        await Task.yield()
    }
    Issue.record("Timeout waiting for feedback to clear")
}
