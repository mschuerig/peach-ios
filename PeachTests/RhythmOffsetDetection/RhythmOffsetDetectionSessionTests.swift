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
    trialToReturn: RhythmOffsetDetectionTrial? = nil,
    currentTime: @escaping () -> Double = { 0.0 }
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
        sampleRate: .standard48000,
        currentTime: currentTime
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

    // MARK: - litDotCount Tests

    @Test("litDotCount starts at 0")
    func litDotCountStartsAtZero() {
        let f = makeSession()
        #expect(f.session.litDotCount == 0)
    }

    @Test("litDotCount increments during pattern playback")
    func litDotCountIncrementsDuringPlayback() async throws {
        let f = makeSession()

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        // After pattern completes, litDotCount should be 4
        #expect(f.session.litDotCount == 4)
    }

    @Test("litDotCount resets on stop")
    func litDotCountResetsOnStop() async throws {
        let f = makeSession()

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.stop()
        #expect(f.session.litDotCount == 0)
    }

    @Test("litDotCount resets at start of new trial")
    func litDotCountResetsAtNewTrial() async throws {
        let f = makeSession()

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.litDotCount == 4)

        // Answer to trigger next trial
        f.session.handleAnswer(direction: .late)
        await f.mockPlayer.waitForPlay(minCount: 2)

        // After second trial completes, litDotCount should be 4 again
        // (it was reset to 0 before the new trial started, then incremented back to 4)
        try await waitForState(f.session, .awaitingAnswer)
        #expect(f.session.litDotCount == 4)
    }

    // MARK: - lastCompletedOffsetPercentage Tests

    @Test("lastCompletedOffsetPercentage is nil initially")
    func lastCompletedOffsetPercentageNilInitially() {
        let f = makeSession()
        #expect(f.session.lastCompletedOffsetPercentage == nil)
    }

    @Test("lastCompletedOffsetPercentage returns value after answer")
    func lastCompletedOffsetPercentageAfterAnswer() async throws {
        let trial = RhythmOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: RhythmOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial)

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(direction: .late)

        let percentage = f.session.lastCompletedOffsetPercentage
        #expect(percentage != nil)
        #expect(percentage! > 0)
    }

    @Test("lastCompletedOffsetPercentage resets on stop")
    func lastCompletedOffsetPercentageResetsOnStop() async throws {
        let f = makeSession()

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(direction: .late)
        #expect(f.session.lastCompletedOffsetPercentage != nil)

        f.session.stop()
        #expect(f.session.lastCompletedOffsetPercentage == nil)
    }

    // MARK: - sessionBestOffsetPercentage Tests

    @Test("sessionBestOffsetPercentage is nil initially")
    func sessionBestNilInitially() {
        let f = makeSession()
        #expect(f.session.sessionBestOffsetPercentage == nil)
    }

    @Test("sessionBestOffsetPercentage updates on correct answer")
    func sessionBestUpdatesOnCorrectAnswer() async throws {
        let trial = RhythmOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: RhythmOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial)

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(direction: .late) // correct answer

        #expect(f.session.sessionBestOffsetPercentage != nil)
        #expect(f.session.sessionBestOffsetPercentage! > 0)
    }

    @Test("sessionBestOffsetPercentage does not update on incorrect answer")
    func sessionBestDoesNotUpdateOnIncorrect() async throws {
        let trial = RhythmOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: RhythmOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial)

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(direction: .early) // wrong answer

        #expect(f.session.sessionBestOffsetPercentage == nil)
    }

    @Test("sessionBestOffsetPercentage resets on stop")
    func sessionBestResetsOnStop() async throws {
        let trial = RhythmOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: RhythmOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial)

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(direction: .late)
        #expect(f.session.sessionBestOffsetPercentage != nil)

        f.session.stop()
        #expect(f.session.sessionBestOffsetPercentage == nil)
    }

    // MARK: - Grid Alignment Tests

    @Test("first pattern establishes grid origin from currentTime")
    func firstPatternEstablishesGridOrigin() async throws {
        var mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        // First pattern should have used the current time as grid origin
        // Verify by checking that the session played without waiting for grid
        #expect(f.mockPlayer.playCallCount == 1)
    }

    @Test("subsequent pattern waits for grid alignment")
    func subsequentPatternWaitsForGrid() async throws {
        // At 80 BPM, quarter note = 0.75s
        // Grid origin at t=10.0, so grid points are 10.0, 10.75, 11.5, 12.25, ...
        var mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        // Simulate feedback ending at t=10.3 (between grid points 10.0 and 10.75)
        mockTime = 10.3
        f.session.handleAnswer(direction: .late)
        #expect(f.session.state == .showingFeedback)

        // After feedback, session should enter waitingForGrid
        try await waitForState(f.session, .waitingForGrid)
        #expect(f.session.state == .waitingForGrid)

        // Eventually should advance to playingPattern for next trial
        try await waitForState(f.session, .awaitingAnswer, timeout: .seconds(3))
        #expect(f.mockPlayer.playCallCount >= 2)
    }

    @Test("grid is never skipped even with short wait")
    func gridNeverSkipped() async throws {
        // At 80 BPM, quarter note = 0.75s
        // Grid origin at t=10.0, grid points at 10.0, 10.75, 11.5, ...
        var mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        // Simulate feedback ending just before a grid point (t=10.74)
        mockTime = 10.74
        f.session.handleAnswer(direction: .late)

        // Should still wait for grid point at 10.75
        try await waitForState(f.session, .waitingForGrid)
        #expect(f.session.state == .waitingForGrid)

        f.session.stop()
    }

    @Test("variable answer and feedback times produce grid-aligned patterns")
    func variableTimesProduceGridAlignedPatterns() async throws {
        // At 80 BPM, quarter note = 0.75s
        var mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        let settings = RhythmOffsetDetectionSettings(
            tempo: TempoBPM(80),
            feedbackDuration: .milliseconds(50)
        )

        f.session.start(settings: settings)
        try await waitForState(f.session, .awaitingAnswer)

        // First answer at variable time
        mockTime = 10.5
        f.session.handleAnswer(direction: .late)
        try await waitForState(f.session, .awaitingAnswer, timeout: .seconds(3))

        // Second answer at different time
        mockTime = 11.8
        f.session.handleAnswer(direction: .late)
        try await waitForState(f.session, .awaitingAnswer, timeout: .seconds(3))

        // Should have played 3 patterns total
        #expect(f.mockPlayer.playCallCount >= 3)

        f.session.stop()
    }

    @Test("waitingForGrid state keeps buttons disabled")
    func waitingForGridKeepsButtonsDisabled() async throws {
        var mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        // Set time between grid points
        mockTime = 10.3
        f.session.handleAnswer(direction: .late)

        try await waitForState(f.session, .waitingForGrid)

        // Buttons should be disabled (only enabled in awaitingAnswer)
        #expect(RhythmOffsetDetectionScreen.buttonsEnabled(state: f.session.state) == false)

        f.session.stop()
    }

    @Test("grid origin resets on stop")
    func gridOriginResetsOnStop() async throws {
        var mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.stop()

        // Start again with different time — should establish new grid origin
        mockTime = 20.0
        f.session.start(settings: defaultRhythmSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playCallCount >= 2)
        f.session.stop()
    }
}
