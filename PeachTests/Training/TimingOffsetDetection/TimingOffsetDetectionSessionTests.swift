import Testing
import Foundation
@testable import Peach

#if PEACH_RESEARCH
// MARK: - Default Test Settings

private let defaultTimingSettings = TimingOffsetDetectionSettings(
    tempo: TempoBPM(80),
    feedbackDuration: .milliseconds(50)
)

// MARK: - Shared Test Fixture

private struct TimingOffsetDetectionSessionFixture {
    let session: TimingOffsetDetectionSession
    let sequencer: MockBeatSequencer
    let strategy: MockNextTimingOffsetDetectionStrategy
    let observer: MockTimingOffsetDetectionObserver
    let profile: PerceptualProfile
    let maxRepetitions: Int?

    var samplesPerBeat: Int64 { sequencer.samplesPerBeat }
    var samplesPerSubdivision: Int64 { sequencer.samplesPerBeat / Int64(TimingOffsetDetectionSession.subdivisionsPerBeat) }

    /// Sample position at the boundary tick of the given full cycle index
    /// (e.g. cycle 1 = end of first cycle = `samplesPerBeat * 1`).
    func samplePositionAtCycleBoundary(_ cycleIndex: Int) -> Int64 {
        Int64(cycleIndex) * samplesPerBeat
    }

    /// Default test settings, optionally overriding `maxRepetitions`. Mirrors `defaultTimingSettings`
    /// but lets each test choose a per-trial cap (defaults to the production default).
    var settings: TimingOffsetDetectionSettings {
        if let maxRepetitions {
            return TimingOffsetDetectionSettings(
                tempo: TempoBPM(80),
                feedbackDuration: .milliseconds(50),
                maxRepetitions: maxRepetitions
            )
        }
        return defaultTimingSettings
    }
}

private func makeSession(
    trialToReturn: TimingOffsetDetectionTrial? = nil,
    maxRepetitions: Int? = nil,
    currentTime: @escaping () -> Double = { 0.0 }
) -> TimingOffsetDetectionSessionFixture {
    let sequencer = MockBeatSequencer()
    // MockBeatSequencer exposes samplesPerBeat directly; it isn't derived from the TempoBPM passed via start(tempo:).
    sequencer.samplesPerBeat = 22050
    sequencer.sampleRate = .standard44100

    let strategy = MockNextTimingOffsetDetectionStrategy()
    let observer = MockTimingOffsetDetectionObserver()
    let profile = PerceptualProfile()

    if let trial = trialToReturn {
        strategy.trialToReturn = trial
    }

    let session = TimingOffsetDetectionSession(
        beatSequencer: sequencer,
        strategy: strategy,
        profile: profile,
        observers: [observer],
        audioInterruptionObserver: NoOpAudioInterruptionObserver(),
        currentTime: currentTime
    )

    return TimingOffsetDetectionSessionFixture(
        session: session,
        sequencer: sequencer,
        strategy: strategy,
        observer: observer,
        profile: profile,
        maxRepetitions: maxRepetitions
    )
}

// MARK: - Async Test Helpers

private func waitForState(
    _ session: TimingOffsetDetectionSession,
    _ expectedState: TimingOffsetDetectionSessionState,
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

@Suite("TimingOffsetDetectionSession Tests")
struct TimingOffsetDetectionSessionTests {

    @Test("starts in idle state")
    func startsInIdleState() {
        let f = makeSession()
        #expect(f.session.state == .idle)
        #expect(f.session.isIdle)
        #expect(f.session.litDotCount == 0)
    }

    // MARK: - Start / Loop Lifecycle

    @Test("start transitions to playingPatternLoop and starts the sequencer")
    func startTransitionsToPlayingPatternLoop() async {
        let f = makeSession()

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()

        #expect(f.session.state == .playingPatternLoop)
        #expect(f.sequencer.startCallCount == 1)
        #expect(f.sequencer.lastTempo == TempoBPM(80))
        #expect(f.strategy.nextTimingOffsetDetectionTrialCallCount == 1)

        f.session.stop()
    }

    @Test("session provides itself as beat provider to sequencer")
    func sessionProvidesItselfAsBeatProvider() async {
        let f = makeSession()
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()

        #expect(f.sequencer.lastBeatProvider is TimingOffsetDetectionSession)

        f.session.stop()
    }

    @Test("start ignored when already running")
    func startIgnoredWhenAlreadyRunning() async {
        let f = makeSession()
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()

        f.session.start(settings: defaultTimingSettings)

        #expect(f.strategy.nextTimingOffsetDetectionTrialCallCount == 1)
        f.session.stop()
    }

    // MARK: - nextBeat Shape (I/O matrix: pattern shape)

    @Test("nextBeat returns 4-subdivision beat with accent on first and offset on third")
    func nextBeatShape() async throws {
        let lateTrial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: lateTrial)

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()

        let beat = f.session.nextBeat()

        #expect(beat.subdivisions.count == 4)

        // Subdivision 0: accent, no offset
        guard case let .note(velocity0, offset0) = beat.subdivisions[0] else {
            Issue.record("Expected subdivision 0 to be a note")
            return
        }
        #expect(velocity0 == RhythmVelocity.accent)
        #expect(offset0 == .zero)

        // Subdivision 1: normal, no offset
        guard case let .note(velocity1, offset1) = beat.subdivisions[1] else {
            Issue.record("Expected subdivision 1 to be a note")
            return
        }
        #expect(velocity1 == RhythmVelocity.normal)
        #expect(offset1 == .zero)

        // Subdivision 2 (tested note): normal, carries trial offset
        guard case let .note(velocity2, offset2) = beat.subdivisions[2] else {
            Issue.record("Expected subdivision 2 to be a note")
            return
        }
        #expect(velocity2 == RhythmVelocity.normal)
        #expect(offset2 == lateTrial.offset.duration)

        // Subdivision 3: normal, no offset
        guard case let .note(velocity3, offset3) = beat.subdivisions[3] else {
            Issue.record("Expected subdivision 3 to be a note")
            return
        }
        #expect(velocity3 == RhythmVelocity.normal)
        #expect(offset3 == .zero)

        f.session.stop()
    }

    @Test("nextBeat carries early (negative) offset on third subdivision")
    func nextBeatWithEarlyOffset() async throws {
        let earlyTrial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(-50))
        )
        let f = makeSession(trialToReturn: earlyTrial)

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()

        let beat = f.session.nextBeat()

        guard case let .note(_, offset2) = beat.subdivisions[2] else {
            Issue.record("Expected subdivision 2 to be a note")
            return
        }
        #expect(offset2 == earlyTrial.offset.duration)
        #expect(offset2 < .zero)

        f.session.stop()
    }

    @Test("nextBeat after stop returns a silent (all-rest) beat so a refill cannot leak audible clicks")
    func nextBeatAfterStopReturnsFallback() async {
        let f = makeSession()
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()

        f.session.stop()

        let beat = f.session.nextBeat()
        #expect(beat.subdivisions.count == 4)
        for subdivision in beat.subdivisions {
            guard case .rest = subdivision else {
                Issue.record("Expected .rest in fallback beat, got \(subdivision)")
                return
            }
        }
        // litDotCount remains 0 — the sequencer-driven loop is gone.
        f.sequencer.currentSamplePosition = 0
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 0)
    }

    @Test("nextBeat returns structurally identical beats across repeated calls within a trial (looping invariant)")
    func nextBeatStableAcrossRepetitions() async throws {
        let lateTrial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: lateTrial)
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        // Sequencer will request many beats over the life of one trial. Every request
        // must return the same beat shape — gapless looping requires beat-by-beat stability.
        let beats = (0..<5).map { _ in f.session.nextBeat() }
        for beat in beats {
            #expect(beat == beats[0], "All beats within a trial must be structurally identical")
        }

        f.session.stop()
    }

    @Test("testedNoteIndex is consistent with help text ordinal")
    func testedNoteIndexConsistentWithHelpText() {
        // Verify the English source key (locale-independent) embeds the correct ordinal.
        // If testedNoteIndex changes, this test forces updating the localization key too.
        let englishKey = "You'll hear four clicks — a short rhythmic pattern. The **third** click may arrive slightly **early** or **late**. Your job is to decide which one it was."
        let ordinals = ["**first**", "**second**", "**third**", "**fourth**"]
        let expectedOrdinal = ordinals[TimingOffsetDetectionSession.testedNoteIndex]
        #expect(englishKey.contains(expectedOrdinal),
                "Localization key must contain '\(expectedOrdinal)' to match testedNoteIndex=\(TimingOffsetDetectionSession.testedNoteIndex)")
    }

    // MARK: - litDotCount Tracking

    @Test("litDotCount cycles 1→2→3→4→1 as samplePosition advances")
    func litDotCountCyclesAcrossLoopIterations() async throws {
        let f = makeSession()
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()

        try await waitForState(f.session, .playingPatternLoop)

        // Inside first beat: subdivision 0 → litDotCount 1
        f.sequencer.currentSamplePosition = 0
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 1)

        // subdivision 1 → 2
        f.sequencer.currentSamplePosition = f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 2)

        // subdivision 2 → 3
        f.sequencer.currentSamplePosition = 2 * f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 3)

        // subdivision 3 → 4
        f.sequencer.currentSamplePosition = 3 * f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 4)

        // Second beat, subdivision 0 → 1 (loop boundary)
        f.sequencer.currentSamplePosition = 4 * f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 1)

        // Second beat, subdivision 2 → 3
        f.sequencer.currentSamplePosition = 6 * f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 3)

        f.session.stop()
    }

    @Test("trackingTask updates litDotCount as samplePosition advances and stops on session stop")
    func trackingTaskUpdatesLitDotCount() async throws {
        let f = makeSession()
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.sequencer.currentSamplePosition = 2 * f.samplesPerSubdivision
        let deadline = ContinuousClock.now + .milliseconds(200)
        while ContinuousClock.now < deadline && f.session.litDotCount != 3 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(f.session.litDotCount == 3)

        f.session.stop()
        #expect(f.session.litDotCount == 0)
        f.sequencer.currentSamplePosition = 5 * f.samplesPerSubdivision
        try await Task.sleep(for: .milliseconds(30))
        #expect(f.session.litDotCount == 0, "Tracking loop must be cancelled after stop")
    }

    @Test("litDotCount only republishes on subdivision change (gating Observation churn)")
    func litDotCountGatesObservationChurn() async throws {
        let f = makeSession()
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        // Drive into subdivision 1
        f.sequencer.currentSamplePosition = f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 2)

        // Tick within the same subdivision — should not change litDotCount
        f.sequencer.currentSamplePosition = f.samplesPerSubdivision + 1
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 2)

        f.session.stop()
    }

    @Test("litDotCount is zero before sequencer is running")
    func litDotCountZeroOutsidePlayingPatternLoop() async {
        let f = makeSession()
        #expect(f.session.litDotCount == 0)
        // Even if we drive samplePosition while idle, evaluation is a no-op.
        f.sequencer.currentSamplePosition = 5 * f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 0)
    }

    @Test("litDotCount resets to 0 on stop")
    func litDotCountResetsOnStop() async throws {
        let f = makeSession()
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.sequencer.currentSamplePosition = 2 * f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 3)

        f.session.stop()
        #expect(f.session.litDotCount == 0)
    }

    @Test("litDotCount is 0 in waitingForGrid and showingFeedback states")
    func litDotCountZeroInNonLoopStates() async throws {
        var mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        // Advance some subdivisions so litDotCount > 0
        f.sequencer.currentSamplePosition = 2 * f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 3)

        // Answer mid-loop: leaves playingPatternLoop and resets litDotCount.
        mockTime = 10.3
        f.session.handleAnswer(direction: .late)
        #expect(f.session.state == .showingFeedback)
        #expect(f.session.litDotCount == 0)

        // Wait for the feedback timer to advance state to waitingForGrid.
        try await waitForState(f.session, .waitingForGrid)
        #expect(f.session.litDotCount == 0)

        f.session.stop()
    }

    // MARK: - Answer Handling (I/O matrix: user answers mid-loop)

    @Test("handleAnswer mid-loop transitions to showingFeedback and stops the sequencer")
    func handleAnswerMidLoopStopsSequencer() async throws {
        let lateTrial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: lateTrial)

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.session.handleAnswer(direction: .late)

        #expect(f.session.state == .showingFeedback)
        #expect(f.observer.completedCallCount == 1)
        #expect(f.observer.lastResult?.isCorrect == true)
        #expect(f.observer.lastResult?.offset == lateTrial.offset)
        #expect(f.observer.lastResult?.tempo == lateTrial.tempo)

        // The sequencer is stopped to silence audio.
        await f.sequencer.waitForStop()
        #expect(f.sequencer.stopCallCount >= 1)

        f.session.stop()
    }

    @Test("handleAnswer records incorrect result when direction wrong")
    func handleAnswerRecordsIncorrectResult() async throws {
        let lateTrial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: lateTrial)

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.session.handleAnswer(direction: .early)

        #expect(f.observer.completedCallCount == 1)
        #expect(f.observer.lastResult?.isCorrect == false)
    }

    @Test("handleAnswer between repetitions (loop boundary) produces the same outcome as a mid-loop answer")
    func handleAnswerAtLoopBoundary() async throws {
        // Spec I/O matrix: "Same as [mid-loop]; no special handling needed at boundary."
        let lateTrial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: lateTrial)
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        // Sit at the loop boundary (samplePosition between repetitions).
        f.sequencer.currentSamplePosition = f.samplesPerBeat
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 1)

        f.session.handleAnswer(direction: .late)

        #expect(f.session.state == .showingFeedback)
        #expect(f.observer.completedCallCount == 1)
        // Outcome is byte-identical to a mid-loop answer for the same trial.
        let result = try #require(f.observer.lastResult)
        #expect(result.isCorrect == true)
        #expect(result.offset == lateTrial.offset)
        #expect(result.tempo == lateTrial.tempo)

        f.session.stop()
    }

    @Test("handleAnswer ignored when not in playingPatternLoop")
    func handleAnswerIgnoredWhenNotInLoop() async {
        let f = makeSession()
        // While idle
        f.session.handleAnswer(direction: .late)
        #expect(f.observer.completedCallCount == 0)

        // While showingFeedback (post-answer)
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        f.session.handleAnswer(direction: .late)
        #expect(f.session.state == .showingFeedback)

        // Second answer in showingFeedback is ignored.
        f.session.handleAnswer(direction: .early)
        #expect(f.observer.completedCallCount == 1)

        f.session.stop()
    }

    // MARK: - Feedback / Grid Alignment (I/O matrix: feedback completes, grid aligns)

    @Test("feedback completes, grid aligns, new trial begins")
    func feedbackThenGridAlignmentStartsNextTrial() async throws {
        let f = makeSession(currentTime: { 10.0 })

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.session.handleAnswer(direction: .late)

        // Wait for next start of sequencer.
        await f.sequencer.waitForStart(minCount: 2)

        #expect(f.sequencer.startCallCount >= 2)
        #expect(f.strategy.nextTimingOffsetDetectionTrialCallCount >= 2)

        // After restart, litDotCount resumes at 1 from subdivision 0 of the new trial.
        f.sequencer.currentSamplePosition = 0
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 1)

        f.session.stop()
    }

    @Test("transitions through showingFeedback → waitingForGrid → playingPatternLoop")
    func stateTransitionsAcrossFeedbackAndGrid() async throws {
        var mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        mockTime = 10.3
        f.session.handleAnswer(direction: .late)
        #expect(f.session.state == .showingFeedback)

        try await waitForState(f.session, .waitingForGrid)
        #expect(f.session.state == .waitingForGrid)

        try await waitForState(f.session, .playingPatternLoop, timeout: .seconds(3))
        #expect(f.session.state == .playingPatternLoop)

        f.session.stop()
    }

    // MARK: - Stop (I/O matrix: stop during loop, stop before first trial)

    @Test("stop during loop stops the sequencer and clears state to idle")
    func stopDuringLoopClearsState() async throws {
        let f = makeSession()
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.session.stop()

        #expect(f.session.state == .idle)
        #expect(f.session.isIdle)
        #expect(f.session.showFeedback == false)
        #expect(f.session.isLastAnswerCorrect == nil)
        #expect(f.session.litDotCount == 0)
        #expect(f.session.currentOffsetPercentage == nil)
        await f.sequencer.waitForStop()
        #expect(f.sequencer.stopCallCount >= 1)
    }

    @Test("stop before first trial completes is safe")
    func stopBeforeFirstTrialIsSafe() async {
        let f = makeSession()
        f.session.start(settings: defaultTimingSettings)
        // Immediately stop without awaiting the sequencer start.
        f.session.stop()

        #expect(f.session.isIdle)
        #expect(f.observer.completedCallCount == 0)
    }

    @Test("stop when already idle is a no-op")
    func stopWhenIdleIsNoOp() async {
        let f = makeSession()
        #expect(f.session.isIdle)
        f.session.stop()
        #expect(f.session.isIdle)
        #expect(f.sequencer.stopCallCount == 0)
    }

    // MARK: - Sequencer Start Failure (I/O matrix: sequencer start fails)

    @Test("sequencer start failure sends audio error and transitions to idle")
    func sequencerStartFailureSendsAudioError() async throws {
        let f = makeSession()
        f.sequencer.shouldThrowError = true
        f.sequencer.errorToThrow = .engineStartFailed("Test error")

        f.session.start(settings: defaultTimingSettings)
        try await waitForState(f.session, .idle)

        #expect(f.session.state == .idle)
        #expect(f.observer.completedCallCount == 0)
    }

    // MARK: - canAcceptAnswer

    @Test("canAcceptAnswer is true only during playingPatternLoop")
    func canAcceptAnswerOnlyDuringLoop() async throws {
        let f = makeSession()
        #expect(f.session.canAcceptAnswer == false)

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)
        #expect(f.session.canAcceptAnswer == true)

        f.session.handleAnswer(direction: .late)
        #expect(f.session.canAcceptAnswer == false)

        f.session.stop()
        #expect(f.session.canAcceptAnswer == false)
    }

    // MARK: - currentOffsetPercentage

    @Test("currentOffsetPercentage reflects current trial")
    func currentOffsetPercentageReflectsTrial() async throws {
        let f = makeSession()
        #expect(f.session.currentOffsetPercentage == nil)

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        let currentOffset = try #require(f.session.currentOffsetPercentage)
        #expect(currentOffset > 0)

        f.session.stop()
        #expect(f.session.currentOffsetPercentage == nil)
    }

    // MARK: - lastCompletedOffsetPercentage

    @Test("lastCompletedOffsetPercentage is nil initially")
    func lastCompletedOffsetPercentageNilInitially() {
        let f = makeSession()
        #expect(f.session.lastCompletedOffsetPercentage == nil)
    }

    @Test("lastCompletedOffsetPercentage returns value after answer")
    func lastCompletedOffsetPercentageAfterAnswer() async throws {
        let trial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial)

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.session.handleAnswer(direction: .late)

        let percentage = try #require(f.session.lastCompletedOffsetPercentage)
        #expect(percentage > 0)
    }

    @Test("lastCompletedOffsetPercentage resets on stop")
    func lastCompletedOffsetPercentageResetsOnStop() async throws {
        let f = makeSession()
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.session.handleAnswer(direction: .late)
        #expect(f.session.lastCompletedOffsetPercentage != nil)

        f.session.stop()
        #expect(f.session.lastCompletedOffsetPercentage == nil)
    }

    // MARK: - sessionBestOffsetPercentage

    @Test("sessionBestOffsetPercentage is nil initially")
    func sessionBestNilInitially() {
        let f = makeSession()
        #expect(f.session.sessionBestOffsetPercentage == nil)
    }

    @Test("sessionBestOffsetPercentage updates on correct answer")
    func sessionBestUpdatesOnCorrectAnswer() async throws {
        let trial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial)

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.session.handleAnswer(direction: .late) // correct

        let sessionBest = try #require(f.session.sessionBestOffsetPercentage)
        #expect(sessionBest > 0)
    }

    @Test("sessionBestOffsetPercentage does not update on incorrect answer")
    func sessionBestDoesNotUpdateOnIncorrect() async throws {
        let trial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial)

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.session.handleAnswer(direction: .early) // wrong

        #expect(f.session.sessionBestOffsetPercentage == nil)
    }

    @Test("sessionBestOffsetPercentage resets on stop")
    func sessionBestResetsOnStop() async throws {
        let trial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial)

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.session.handleAnswer(direction: .late)
        #expect(f.session.sessionBestOffsetPercentage != nil)

        f.session.stop()
        #expect(f.session.sessionBestOffsetPercentage == nil)
    }

    // MARK: - Grid Alignment

    @Test("first pattern establishes grid origin from currentTime")
    func firstPatternEstablishesGridOrigin() async throws {
        let mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        #expect(f.sequencer.startCallCount == 1)
    }

    @Test("grid is never skipped even with short wait")
    func gridNeverSkipped() async throws {
        // At 80 BPM, quarter note = 0.75s; grid points at 10.0, 10.75, ...
        var mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        // Simulate feedback ending just before a grid point (t=10.74)
        mockTime = 10.74
        f.session.handleAnswer(direction: .late)

        try await waitForState(f.session, .waitingForGrid)
        #expect(f.session.state == .waitingForGrid)

        f.session.stop()
    }

    @Test("variable answer and feedback times produce grid-aligned patterns")
    func variableTimesProduceGridAlignedPatterns() async throws {
        var mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        mockTime = 10.5
        f.session.handleAnswer(direction: .late)
        await f.sequencer.waitForStart(minCount: 2)

        try await waitForState(f.session, .playingPatternLoop, timeout: .seconds(3))

        mockTime = 11.8
        f.session.handleAnswer(direction: .late)
        await f.sequencer.waitForStart(minCount: 3)

        #expect(f.sequencer.startCallCount >= 3)

        f.session.stop()
    }

    @Test("grid origin resets on stop")
    func gridOriginResetsOnStop() async throws {
        var mockTime = 10.0
        let f = makeSession(currentTime: { mockTime })

        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        f.session.stop()

        mockTime = 20.0
        f.session.start(settings: defaultTimingSettings)
        await f.sequencer.waitForStart(minCount: 2)

        #expect(f.sequencer.startCallCount >= 2)
        f.session.stop()
    }

    // MARK: - Max Repetitions Cap (I/O matrix: cap-reached scenarios)

    @Test("cap reached stops sequencer once, leaves state in playingPatternLoop, resets litDotCount")
    func repetitionCapStopsSequencerWithoutLeavingLoop() async throws {
        let trial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial, maxRepetitions: 3)
        f.session.start(settings: f.settings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        let stopsBefore = f.sequencer.stopCallCount

        // Advance into the middle of cycle 2 (subdivision index 6 → litDotCount 3).
        f.sequencer.currentSamplePosition = f.samplesPerBeat + 2 * f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 3)

        // Trip the cap on the boundary tick of cycle 3 (3 completed cycles).
        f.sequencer.currentSamplePosition = f.samplePositionAtCycleBoundary(3)
        f.session.evaluatePlaybackPosition()

        #expect(f.session.state == .playingPatternLoop, "Cap must not exit playingPatternLoop")
        #expect(f.session.litDotCount == 0, "litDotCount must reset when sequencer stops at the cap")
        #expect(f.observer.completedCallCount == 0, "Cap alone does not notify the observer")

        // Sequencer stop was enqueued; await it to observe the side effect deterministically.
        while f.sequencer.stopCallCount == stopsBefore {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(f.sequencer.stopCallCount == stopsBefore + 1)

        // Polling further past the cap is a no-op: the reducer ignores .repetitionCapReached
        // when state is no longer .playingPatternLoop, and the cancelled trackingTask
        // suppresses real firings. We assert the no-op shape via evaluatePlaybackPosition.
        let stopsAfterCap = f.sequencer.stopCallCount
        f.sequencer.currentSamplePosition = f.samplePositionAtCycleBoundary(5)
        f.session.evaluatePlaybackPosition()
        #expect(f.sequencer.stopCallCount == stopsAfterCap, "Cap firing must not enqueue additional stops on subsequent polls")

        f.session.stop()
    }

    @Test("answer after cap-stop completes the trial through the normal answer path")
    func answerAfterCapCompletesTrial() async throws {
        let trial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial, maxRepetitions: 2)
        f.session.start(settings: f.settings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        // Trip the cap.
        f.sequencer.currentSamplePosition = f.samplePositionAtCycleBoundary(2)
        f.session.evaluatePlaybackPosition()
        #expect(f.session.state == .playingPatternLoop)
        #expect(f.observer.completedCallCount == 0)

        // The user can still submit a direction.
        f.session.handleAnswer(direction: .late)

        #expect(f.session.state == .showingFeedback)
        #expect(f.observer.completedCallCount == 1)
        let result = try #require(f.observer.lastResult)
        #expect(result.isCorrect == true)
        #expect(result.offset == trial.offset)
        #expect(result.tempo == trial.tempo)

        f.session.stop()
    }

    @Test("answer before cap is unchanged — no cap firing, observer notified once via the answer path")
    func answerBeforeCapUnchanged() async throws {
        let trial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial, maxRepetitions: 5)
        f.session.start(settings: f.settings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        // Advance partway through cycle 2 (well before the 5-cycle cap).
        f.sequencer.currentSamplePosition = f.samplesPerBeat + f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.state == .playingPatternLoop)
        #expect(f.session.litDotCount == 2)

        f.session.handleAnswer(direction: .late)

        #expect(f.session.state == .showingFeedback)
        #expect(f.observer.completedCallCount == 1)

        f.session.stop()
    }

    @Test("maxRepetitions == 1 stops the sequencer after exactly one full cycle")
    func capOfOneStopsAfterFirstCycle() async throws {
        let trial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial, maxRepetitions: 1)
        f.session.start(settings: f.settings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        let stopsBefore = f.sequencer.stopCallCount

        // Still inside cycle 1 (subdivision 3 of 4): cap must not fire.
        f.sequencer.currentSamplePosition = 3 * f.samplesPerSubdivision
        f.session.evaluatePlaybackPosition()
        #expect(f.session.litDotCount == 4)
        #expect(f.sequencer.stopCallCount == stopsBefore)

        // Reach the boundary after 1 completed cycle: cap fires.
        f.sequencer.currentSamplePosition = f.samplePositionAtCycleBoundary(1)
        f.session.evaluatePlaybackPosition()
        #expect(f.session.state == .playingPatternLoop)
        #expect(f.session.litDotCount == 0)
        #expect(f.observer.completedCallCount == 0, "User must still submit a direction")

        while f.sequencer.stopCallCount == stopsBefore {
            try await Task.sleep(for: .milliseconds(5))
        }

        f.session.stop()
    }

    @Test("very high maxRepetitions cap never fires — behaviour matches the uncapped loop")
    func veryHighCapNeverFires() async throws {
        let trial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(50))
        )
        let f = makeSession(trialToReturn: trial, maxRepetitions: .max)
        f.session.start(settings: f.settings)
        await f.sequencer.waitForStart()
        try await waitForState(f.session, .playingPatternLoop)

        let stopsBefore = f.sequencer.stopCallCount

        // Advance through several cycles — far beyond any sensible practical cap.
        for cycleIndex in 0..<10 {
            f.sequencer.currentSamplePosition = f.samplePositionAtCycleBoundary(cycleIndex)
            f.session.evaluatePlaybackPosition()
        }

        #expect(f.session.state == .playingPatternLoop)
        #expect(f.sequencer.stopCallCount == stopsBefore, "Cap must not fire under a practical-infinity setting")
        #expect(f.observer.completedCallCount == 0)

        f.session.stop()
    }
}
#endif
