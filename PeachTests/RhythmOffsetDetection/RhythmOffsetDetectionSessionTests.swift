import Testing
import Foundation
@testable import Peach

// MARK: - Default Test Settings

private let defaultRhythmSettings = RhythmOffsetDetectionSettings(
    tempo: TempoBPM(80),
    feedbackDuration: .milliseconds(50)
)

// MARK: - Shared Test Fixture

private struct RhythmOffsetDetectionSessionFixture {
    let session: RhythmOffsetDetectionSession
    let mockPlayer: MockRhythmPlayer
    let mockStrategy: MockNextRhythmOffsetDetectionStrategy
    let mockObserver: MockRhythmOffsetDetectionObserver
    let profile: PerceptualProfile
}

private func makeSession(
    trialToReturn: RhythmOffsetDetectionTrial? = nil
) -> RhythmOffsetDetectionSessionFixture {
    let mockPlayer = MockRhythmPlayer()
    let mockStrategy = MockNextRhythmOffsetDetectionStrategy()
    let mockObserver = MockRhythmOffsetDetectionObserver()
    let profile = PerceptualProfile()

    if let trial = trialToReturn {
        mockStrategy.trialToReturn = trial
    }

    let session = RhythmOffsetDetectionSession(
        rhythmPlayer: mockPlayer,
        strategy: mockStrategy,
        profile: profile,
        observers: [mockObserver],
        sampleRate: .standard48000
    )

    return RhythmOffsetDetectionSessionFixture(
        session: session,
        mockPlayer: mockPlayer,
        mockStrategy: mockStrategy,
        mockObserver: mockObserver,
        profile: profile
    )
}

// MARK: - Async Test Helpers

private func waitForState(
    _ session: RhythmOffsetDetectionSession,
    _ expectedState: RhythmOffsetDetectionSessionState,
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

@Suite("RhythmOffsetDetectionSession Tests")
struct RhythmOffsetDetectionSessionTests {

    @Test("starts in idle state")
    func startsInIdleState() {
        let f = makeSession()
        #expect(f.session.state == .idle)
        #expect(f.session.isIdle)
    }

    @Test("start transitions to playingPattern and calls strategy and rhythm player")
    func startTransitionsToPlayingPattern() async {
        let f = makeSession()

        var capturedState: RhythmOffsetDetectionSessionState?
        f.mockPlayer.onPlayCalled = {
            if capturedState == nil {
                capturedState = f.session.state
            }
        }

        f.session.start(settings: defaultRhythmSettings)
        await f.mockPlayer.waitForPlay()

        #expect(capturedState == .playingPattern)
        #expect(f.mockPlayer.playCallCount >= 1)
        #expect(f.mockStrategy.nextRhythmOffsetDetectionTrialCallCount >= 1)
    }

    @Test("pattern has 4 events with correct sample offsets")
    func patternHas4EventsWithCorrectOffsets() async {
        let f = makeSession()

        f.session.start(settings: defaultRhythmSettings)
        await f.mockPlayer.waitForPlay()

        let pattern = f.mockPlayer.lastPattern
        #expect(pattern != nil)
        #expect(pattern?.events.count == 4)

        guard let events = pattern?.events else { return }

        let tempo = TempoBPM(80)
        let sixteenthDuration = tempo.sixteenthNoteDuration
        let samplesPerSixteenth = Int64(SampleRate.standard48000.rawValue * sixteenthDuration.timeInterval)

        // Events 0-2: regular sixteenth-note intervals
        #expect(events[0].sampleOffset == 0)
        #expect(events[1].sampleOffset == samplesPerSixteenth)
        #expect(events[2].sampleOffset == 2 * samplesPerSixteenth)

        // Event 3: base offset + trial offset
        let trialOffset = RhythmOffset(.milliseconds(50))
        let offsetSamples = Int64(SampleRate.standard48000.rawValue * trialOffset.duration.timeInterval)
        #expect(events[3].sampleOffset == 3 * samplesPerSixteenth + offsetSamples)

        // All events use hi-hat MIDI note
        for event in events {
            #expect(event.midiNote == MIDINote(76))
            #expect(event.velocity == MIDIVelocity(100))
        }
    }

    @Test("transitions to awaitingAnswer after pattern completes")
    func transitionsToAwaitingAnswer() async throws {
        let f = makeSession()

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.state == .awaitingAnswer)
    }

    @Test("handleAnswer records correct result and notifies observers")
    func handleAnswerRecordsCorrectResult() async throws {
        let lateTrial = RhythmOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: RhythmOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: lateTrial)

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(direction: .late)

        #expect(f.mockObserver.completedCallCount == 1)
        #expect(f.mockObserver.lastResult?.isCorrect == true)
        #expect(f.mockObserver.lastResult?.offset == lateTrial.offset)
        #expect(f.mockObserver.lastResult?.tempo == lateTrial.tempo)
    }

    @Test("handleAnswer records incorrect result when direction wrong")
    func handleAnswerRecordsIncorrectResult() async throws {
        let lateTrial = RhythmOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: RhythmOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: lateTrial)

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(direction: .early)

        #expect(f.mockObserver.completedCallCount == 1)
        #expect(f.mockObserver.lastResult?.isCorrect == false)
    }

    @Test("feedback phase transitions and auto-advances to next trial")
    func feedbackPhaseAutoAdvances() async throws {
        let f = makeSession()

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(direction: .late)
        #expect(f.session.state == .showingFeedback)
        #expect(f.session.showFeedback == true)
        #expect(f.session.isLastAnswerCorrect != nil)

        // Wait for feedback to clear and next trial to start
        await f.mockPlayer.waitForPlay(minCount: 2)

        #expect(f.mockPlayer.playCallCount >= 2)
        #expect(f.mockStrategy.nextRhythmOffsetDetectionTrialCallCount >= 2)
    }

    @Test("stop transitions to idle and cancels tasks")
    func stopTransitionsToIdle() async {
        let f = makeSession()

        f.session.start(settings: defaultRhythmSettings)
        await f.mockPlayer.waitForPlay()

        f.session.stop()

        #expect(f.session.state == .idle)
        #expect(f.session.isIdle)
        #expect(f.session.showFeedback == false)
        #expect(f.session.isLastAnswerCorrect == nil)
        #expect(f.session.currentOffsetPercentage == nil)
    }

    @Test("stop when already idle is a no-op")
    func stopWhenIdleIsNoOp() async {
        let f = makeSession()
        #expect(f.session.isIdle)

        f.session.stop()

        #expect(f.session.isIdle)
    }

    @Test("audio error stops session gracefully")
    func audioErrorStopsSession() async throws {
        let f = makeSession()
        f.mockPlayer.shouldThrowError = true
        f.mockPlayer.errorToThrow = .engineStartFailed("Test error")

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .idle)

        #expect(f.session.state == .idle)
    }

    @Test("handleAnswer ignored when not in awaitingAnswer state")
    func handleAnswerIgnoredWhenNotAwaiting() async {
        let f = makeSession()

        // When idle
        f.session.handleAnswer(direction: .late)
        #expect(f.mockObserver.completedCallCount == 0)

        // When playing pattern
        f.session.start(settings: defaultRhythmSettings)
        await f.mockPlayer.waitForPlay()

        // State should be playingPattern at this point
        if f.session.state == .playingPattern {
            f.session.handleAnswer(direction: .late)
            #expect(f.mockObserver.completedCallCount == 0)
        }

        f.session.stop()
    }

    @Test("start ignored when not idle")
    func startIgnoredWhenNotIdle() async throws {
        let f = makeSession()

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        // Second start should be ignored
        f.session.start(settings: defaultRhythmSettings)

        // Strategy should only have been called once (from first start)
        #expect(f.mockStrategy.nextRhythmOffsetDetectionTrialCallCount == 1)

        f.session.stop()
    }

    @Test("currentOffsetPercentage reflects current trial")
    func currentOffsetPercentageReflectsTrial() async throws {
        let f = makeSession()

        #expect(f.session.currentOffsetPercentage == nil)

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.currentOffsetPercentage != nil)
        #expect(f.session.currentOffsetPercentage! > 0)

        f.session.stop()

        #expect(f.session.currentOffsetPercentage == nil)
    }
}
