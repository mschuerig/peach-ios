import Testing
import Foundation
import AVFoundation
@testable import Peach

// MARK: - Default Test Settings

private let defaultSettings = RhythmMatchingSettings(
    tempo: TempoBPM(80),
    feedbackDuration: .milliseconds(50)
)

// MARK: - Shared Test Fixture

private struct RhythmMatchingSessionFixture {
    let session: RhythmMatchingSession
    let mockPlayer: MockRhythmPlayer
    let mockObserver: MockRhythmMatchingObserver
}

private func makeSession() -> RhythmMatchingSessionFixture {
    let mockPlayer = MockRhythmPlayer()
    let mockObserver = MockRhythmMatchingObserver()

    let session = RhythmMatchingSession(
        rhythmPlayer: mockPlayer,
        observers: [mockObserver],
        sampleRate: .standard48000
    )

    return RhythmMatchingSessionFixture(
        session: session,
        mockPlayer: mockPlayer,
        mockObserver: mockObserver
    )
}

// MARK: - Async Test Helpers

private func waitForState(
    _ session: RhythmMatchingSession,
    _ expectedState: RhythmMatchingSessionState,
    timeout: Duration = .seconds(2)
) async throws {
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

// MARK: - Tests

@Suite("RhythmMatchingSession Tests")
struct RhythmMatchingSessionTests {

    @Test("starts in idle state")
    func startsInIdleState() {
        let f = makeSession()
        #expect(f.session.state == .idle)
        #expect(f.session.isIdle)
    }

    @Test("start transitions to playingLeadIn")
    func startTransitionsToPlayingLeadIn() async {
        let f = makeSession()

        var capturedState: RhythmMatchingSessionState?
        f.mockPlayer.onPlayCalled = {
            if capturedState == nil {
                capturedState = f.session.state
            }
        }

        f.session.start(settings: defaultSettings)
        await f.mockPlayer.waitForPlay()

        #expect(capturedState == .playingLeadIn)
        #expect(f.mockPlayer.playCallCount >= 1)
    }

    @Test("start when not idle is ignored")
    func startWhenNotIdleIsIgnored() async throws {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        try await waitForState(f.session, .awaitingTap)

        f.session.start(settings: defaultSettings)

        // Player should only have been called once
        #expect(f.mockPlayer.playCallCount == 1)

        f.session.stop()
    }

    @Test("pattern has exactly 3 events")
    func patternHasExactly3Events() async {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        await f.mockPlayer.waitForPlay()

        let pattern = f.mockPlayer.lastPattern
        #expect(pattern != nil)
        #expect(pattern?.events.count == 3)

        guard let events = pattern?.events else { return }

        let tempo = TempoBPM(80)
        let sixteenthDuration = tempo.sixteenthNoteDuration
        let samplesPerSixteenth = Int64(SampleRate.standard48000.rawValue * sixteenthDuration.timeInterval)

        #expect(events[0].sampleOffset == 0)
        #expect(events[1].sampleOffset == samplesPerSixteenth)
        #expect(events[2].sampleOffset == 2 * samplesPerSixteenth)

        for event in events {
            #expect(event.midiNote == MIDINote(76))
            #expect(event.velocity == MIDIVelocity(100))
        }

        f.session.stop()
    }

    @Test("transitions from playingLeadIn to awaitingTap")
    func transitionsToAwaitingTap() async throws {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        try await waitForState(f.session, .awaitingTap)

        #expect(f.session.state == .awaitingTap)

        f.session.stop()
    }

    @Test("handleTap transitions to showingFeedback and notifies observers")
    func handleTapTransitionsToFeedback() async throws {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        try await waitForState(f.session, .awaitingTap)

        f.session.handleTap()

        #expect(f.session.state == .showingFeedback)
        #expect(f.session.showFeedback == true)
        #expect(f.mockObserver.completedCallCount == 1)
        #expect(f.mockObserver.lastResult?.tempo == TempoBPM(80))
        #expect(f.mockObserver.lastResult?.expectedOffset == RhythmOffset(.zero))

        f.session.stop()
    }

    @Test("handleTap when not awaitingTap is ignored")
    func handleTapIgnoredWhenNotAwaiting() async {
        let f = makeSession()

        // When idle
        f.session.handleTap()
        #expect(f.mockObserver.completedCallCount == 0)

        // When playing lead-in
        f.session.start(settings: defaultSettings)
        await f.mockPlayer.waitForPlay()

        if f.session.state == .playingLeadIn {
            f.session.handleTap()
            #expect(f.mockObserver.completedCallCount == 0)
        }

        f.session.stop()
    }

    @Test("feedback auto-starts next lead-in after duration")
    func feedbackAutoAdvances() async throws {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        try await waitForState(f.session, .awaitingTap)

        f.session.handleTap()
        #expect(f.session.state == .showingFeedback)

        // Wait for feedback to clear and next trial to start
        await f.mockPlayer.waitForPlay(minCount: 2)

        #expect(f.mockPlayer.playCallCount >= 2)

        f.session.stop()
    }

    @Test("stop transitions to idle and cancels playback")
    func stopTransitionsToIdle() async {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        await f.mockPlayer.waitForPlay()

        f.session.stop()

        #expect(f.session.state == .idle)
        #expect(f.session.isIdle)
        #expect(f.session.showFeedback == false)
        #expect(f.session.litDotCount == 0)
        #expect(f.session.lastUserOffsetPercentage == nil)
    }

    @Test("stop when idle is no-op")
    func stopWhenIdleIsNoOp() {
        let f = makeSession()
        #expect(f.session.isIdle)

        f.session.stop()

        #expect(f.session.isIdle)
    }

    @Test("interruption stops session")
    func interruptionStopsSession() async throws {
        let notificationCenter = NotificationCenter()
        let mockPlayer = MockRhythmPlayer()
        let session = RhythmMatchingSession(
            rhythmPlayer: mockPlayer,
            sampleRate: .standard48000,
            notificationCenter: notificationCenter
        )

        session.start(settings: defaultSettings)
        try await waitForState(session, .awaitingTap)

        notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.isIdle)
    }

    @Test("litDotCount increments 1, 2, 3 during lead-in and 4 on tap")
    func litDotCountIncrements() async throws {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        try await waitForState(f.session, .awaitingTap)

        // After lead-in completes, litDotCount should be 3
        #expect(f.session.litDotCount == 3)

        // After tap, litDotCount should be 4
        f.session.handleTap()
        #expect(f.session.litDotCount == 4)

        f.session.stop()
    }

    @Test("litDotCount resets on stop")
    func litDotCountResetsOnStop() async throws {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        try await waitForState(f.session, .awaitingTap)

        f.session.stop()
        #expect(f.session.litDotCount == 0)
    }

    @Test("litDotCount resets at start of new trial")
    func litDotCountResetsAtNewTrial() async throws {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        try await waitForState(f.session, .awaitingTap)
        #expect(f.session.litDotCount == 3)

        f.session.handleTap()
        #expect(f.session.litDotCount == 4)

        // Wait for next trial
        await f.mockPlayer.waitForPlay(minCount: 2)
        try await waitForState(f.session, .awaitingTap)

        // After second lead-in, litDotCount should be 3 again
        #expect(f.session.litDotCount == 3)

        f.session.stop()
    }

    @Test("lastUserOffsetPercentage is nil initially")
    func lastUserOffsetPercentageNilInitially() {
        let f = makeSession()
        #expect(f.session.lastUserOffsetPercentage == nil)
    }

    @Test("lastUserOffsetPercentage updates after tap")
    func lastUserOffsetPercentageUpdatesAfterTap() async throws {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        try await waitForState(f.session, .awaitingTap)

        f.session.handleTap()

        #expect(f.session.lastUserOffsetPercentage != nil)

        f.session.stop()
    }

    @Test("lastUserOffsetPercentage resets on stop")
    func lastUserOffsetPercentageResetsOnStop() async throws {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        try await waitForState(f.session, .awaitingTap)

        f.session.handleTap()
        #expect(f.session.lastUserOffsetPercentage != nil)

        f.session.stop()
        #expect(f.session.lastUserOffsetPercentage == nil)
    }

    @Test("observer receives CompletedRhythmMatchingTrial with correct tempo and offsets")
    func observerReceivesCorrectTrial() async throws {
        let f = makeSession()

        f.session.start(settings: defaultSettings)
        try await waitForState(f.session, .awaitingTap)

        f.session.handleTap()

        #expect(f.mockObserver.completedCallCount == 1)
        let trial = f.mockObserver.lastResult
        #expect(trial != nil)
        #expect(trial?.tempo == TempoBPM(80))
        #expect(trial?.expectedOffset == RhythmOffset(.zero))
        // userOffset should be a valid RhythmOffset (exact value depends on timing)
        #expect(trial?.userOffset != nil)

        f.session.stop()
    }

    @Test("audio error stops session gracefully")
    func audioErrorStopsSession() async throws {
        let f = makeSession()
        f.mockPlayer.shouldThrowError = true
        f.mockPlayer.errorToThrow = .engineStartFailed("Test error")

        f.session.start(settings: defaultSettings)
        try await waitForState(f.session, .idle)

        #expect(f.session.state == .idle)
    }
}
