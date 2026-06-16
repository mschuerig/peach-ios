import Foundation
import Testing
@testable import Peach

#if PEACH_RESEARCH
@Suite("ContinuousRhythmMatchingSession")
struct ContinuousRhythmMatchingSessionTests {

    // MARK: - Test Fixture

    private struct Fixture {
        let session: ContinuousRhythmMatchingSession
        let sequencer: MockBeatSequencer
        let observer: MockContinuousRhythmMatchingObserver
        let notificationCenter: NotificationCenter

        func defaultSettings(
            tempo: TempoBPM = TempoBPM(120),
            enabledGapPositions: Set<BeatPosition> = [.fourth]
        ) -> ContinuousRhythmMatchingSettings {
            ContinuousRhythmMatchingSettings(
                tempo: tempo,
                enabledGapPositions: enabledGapPositions
            )
        }

        var samplesPerBeat: Int64 { sequencer.samplesPerBeat }
        var samplesPerSubdivision: Int64 { sequencer.samplesPerBeat / 4 }
    }

    private struct MIDIFixture {
        let session: ContinuousRhythmMatchingSession
        let sequencer: MockBeatSequencer
        let observer: MockContinuousRhythmMatchingObserver
        let midiInput: MockMIDIInput
        let notificationCenter: NotificationCenter

        func defaultSettings(
            tempo: TempoBPM = TempoBPM(120),
            enabledGapPositions: Set<BeatPosition> = [.fourth]
        ) -> ContinuousRhythmMatchingSettings {
            ContinuousRhythmMatchingSettings(
                tempo: tempo,
                enabledGapPositions: enabledGapPositions
            )
        }

        var samplesPerBeat: Int64 { sequencer.samplesPerBeat }
        var samplesPerSubdivision: Int64 { sequencer.samplesPerBeat / 4 }
    }

    private func makeSession() -> Fixture {
        let sequencer = MockBeatSequencer()
        sequencer.samplesPerBeat = 22050  // 120 BPM @ 44100 Hz
        sequencer.sampleRate = .standard44100

        let observer = MockContinuousRhythmMatchingObserver()
        let notificationCenter = NotificationCenter()

        let session = ContinuousRhythmMatchingSession(
            beatSequencer: sequencer,
            observers: [observer]
        )

        return Fixture(
            session: session,
            sequencer: sequencer,
            observer: observer,
            notificationCenter: notificationCenter
        )
    }

    private func makeSessionWithMIDI() -> MIDIFixture {
        let sequencer = MockBeatSequencer()
        sequencer.samplesPerBeat = 22050
        sequencer.sampleRate = .standard44100

        let observer = MockContinuousRhythmMatchingObserver()
        let midiInput = MockMIDIInput()
        let notificationCenter = NotificationCenter()

        let session = ContinuousRhythmMatchingSession(
            beatSequencer: sequencer,
            observers: [observer],
            midiInput: midiInput
        )

        return MIDIFixture(
            session: session,
            sequencer: sequencer,
            observer: observer,
            midiInput: midiInput,
            notificationCenter: notificationCenter
        )
    }

    // MARK: - Initial State

    @Test("starts in idle state")
    func startsInIdleState() async {
        let f = makeSession()
        #expect(f.session.isIdle)
        #expect(f.session.isRunning == false)
        #expect(f.session.currentBeatPosition == nil)
        #expect(f.session.gapPositionInCurrentBeat == nil)
        #expect(f.session.cyclesInCurrentTrial == 0)
        #expect(f.session.lastTrialResult == nil)
    }

    // MARK: - Start

    @Test("start begins beat sequencer")
    func startBeginsBeatSequencer() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings())

        await f.sequencer.waitForStart()

        #expect(f.session.isRunning)
        #expect(f.session.isIdle == false)
        #expect(f.sequencer.startCallCount == 1)
        #expect(f.sequencer.lastTempo == TempoBPM(120))

        f.session.stop()
    }

    @Test("start when already running is ignored")
    func startWhenAlreadyRunningIsIgnored() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings())
        await f.sequencer.waitForStart()

        f.session.start(settings: f.defaultSettings())

        #expect(f.sequencer.startCallCount == 1)

        f.session.stop()
    }

    // MARK: - Stop

    @Test("stop transitions to idle")
    func stopTransitionsToIdle() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings())
        await f.sequencer.waitForStart()

        f.session.stop()

        #expect(f.session.isIdle)
        #expect(f.session.isRunning == false)
        #expect(f.session.currentBeatPosition == nil)
        #expect(f.session.gapPositionInCurrentBeat == nil)
        #expect(f.session.cyclesInCurrentTrial == 0)
    }

    @Test("stop when already idle is no-op")
    func stopWhenAlreadyIdleIsNoOp() async {
        let f = makeSession()
        f.session.stop()
        #expect(f.session.isIdle)
    }

    @Test("stop discards incomplete trial")
    func stopDiscardsIncompleteTrial() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Populate gap positions and record a few hits
        for i in 0..<5 {
            _ = f.session.nextBeat()
            // Gap at .fourth = position index 3 within beat i
            let gapSamplePosition = Int64(i) * f.samplesPerBeat
                + Int64(3) * f.samplesPerSubdivision
            f.sequencer.currentSamplePosition = gapSamplePosition + 220 // ~5ms late at 44100 Hz
            f.session.handleTap()
        }

        f.session.stop()

        #expect(f.observer.completedCallCount == 0)
        #expect(f.session.lastTrialResult == nil)
    }

    // MARK: - Gap Selection (nextBeat)

    @Test("nextBeat selects gap from enabled positions")
    func nextBeatSelectsFromEnabledPositions() async {
        let f = makeSession()
        let enabledPositions: Set<BeatPosition> = [.second, .third]
        f.session.start(settings: f.defaultSettings(enabledGapPositions: enabledPositions))
        await f.sequencer.waitForStart()

        for _ in 0..<20 {
            let beat = f.session.nextBeat()
            let gapIndex = beat.subdivisions.firstIndex { if case .rest = $0 { return true } else { return false } }
            let position = try? #require(gapIndex.flatMap { BeatPosition(rawValue: $0) })
            #expect(enabledPositions.contains(position!))
        }

        f.session.stop()
    }

    @Test("nextBeat with single enabled position always returns it")
    func nextBeatWithSinglePositionAlwaysReturnsIt() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.second]))
        await f.sequencer.waitForStart()

        for _ in 0..<10 {
            let beat = f.session.nextBeat()
            // gap at .second means subdivisions[1] is .rest
            if case .rest = beat.subdivisions[1] {
                // OK
            } else {
                Issue.record("expected subdivision[1] to be .rest")
            }
        }

        f.session.stop()
    }

    @Test("nextBeat is side-effect-free — does not record gap results")
    func nextBeatIsSideEffectFree() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings())
        await f.sequencer.waitForStart()

        for _ in 0..<20 {
            _ = f.session.nextBeat()
        }

        #expect(f.session.cyclesInCurrentTrial == 0)
        #expect(f.observer.completedCallCount == 0)

        f.session.stop()
    }

    @Test("nextBeat after stop does not mutate session state")
    func nextBeatAfterStopDoesNotMutateState() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        f.session.stop()
        #expect(f.session.gapPositionInCurrentBeat == nil)

        // Simulate the beat sequencer's provider calling nextBeat after stop.
        let fallback = f.session.nextBeat()
        // Fallback returns a beat with gap at .fourth (subdivisions[3] is .rest)
        if case .rest = fallback.subdivisions[3] {
            // OK
        } else {
            Issue.record("expected fallback subdivision[3] to be .rest")
        }

        // gapPositionInCurrentBeat must stay nil — the fallback beat must not be tracked.
        f.sequencer.currentSamplePosition = 0
        f.session.evaluatePlaybackPosition()
        #expect(f.session.gapPositionInCurrentBeat == nil)
    }

    // MARK: - Tap Evaluation

    @Test("tap inside evaluation window records hit with correct offset")
    func tapInsideWindowRecordsHit() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat() // beat 0: gap at .fourth

        // Gap at .fourth in beat 0: sample position = 3 * samplesPerSubdivision
        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition + 441 // ~10ms late at 44100 Hz

        f.session.handleTap()

        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }

    @Test("tap outside evaluation window is ignored")
    func tapOutsideWindowIsIgnored() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        // Tap one full subdivision away — within beat 0 but outside the half-subdivision window
        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition + f.samplesPerSubdivision

        f.session.handleTap()

        #expect(f.session.cyclesInCurrentTrial == 0)

        f.session.stop()
    }

    @Test("double tap in same beat is ignored")
    func doubleTapInSameBeatIsIgnored() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition + 220

        f.session.handleTap()
        f.session.handleTap()

        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }

    // MARK: - Miss Detection via Tracking

    // MARK: - Trial-start race against stale samplePosition (PF-011)

    /// Regression for the PF-011 trial-start race against CRM's cycle-miss
    /// accumulator: between `beatSequencer.start(...)` returning and the
    /// render thread observing the generation bump that resets
    /// `samplePosition` to 0, the polling task can sample a stale large value.
    /// Without the gate, the `while lastEvaluatedCycleIndex < playingCycleIndex - 1`
    /// loop would fire 16 `cycleMissed` events in one tick and silently
    /// complete the trial.
    ///
    /// The mock's `start()` mirrors the real engine by leaving
    /// `currentSamplePosition` untouched — the test pre-sets a stale value and
    /// later calls `flushDeferredReset()` to model the render-thread's deferred
    /// reset. The polling gate captures the pre-start sample position as a
    /// stale upper bound and skips cycle-miss accumulation until the
    /// render-thread reset is observed.
    @Test("no cycleMissed accumulation on stale samplePosition observed before render-thread reset")
    func trialStartDoesNotAccumulateMissesOnStaleSamplePosition() async {
        let f = makeSession()

        // Simulate a previous trial's accumulated sample position — far past
        // any cycle the trial would actually reach. The mock's `start()`
        // preserves this stale value until `flushDeferredReset()` is called.
        f.sequencer.currentSamplePosition = f.samplesPerBeat * 100

        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Without the gate, the cycle-miss loop would fire 16 `cycleMissed`
        // events and complete the trial. With the gate, `cyclesInCurrentTrial`
        // stays at 0 until the reset is observed.
        f.session.evaluatePlaybackPosition()
        #expect(f.session.cyclesInCurrentTrial == 0, "No cycle misses accumulated on stale read")
        #expect(f.session.isRunning, "Trial remains running rather than auto-completing on the stale read")

        // Render-thread reset observed.
        f.sequencer.flushDeferredReset()

        // Advance partway into beat 1 — beat 0 was missed, gate released.
        _ = f.session.nextBeat() // beat 0
        _ = f.session.nextBeat() // beat 1
        f.sequencer.currentSamplePosition = f.samplesPerBeat + f.samplesPerBeat / 2
        f.session.evaluatePlaybackPosition()
        #expect(f.session.cyclesInCurrentTrial == 1, "Trial proceeds normally once the gate releases")

        f.session.stop()
    }

    @Test("missed gap is recorded when beat advances without tap")
    func missedGapRecordedWhenBeatAdvances() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat() // beat 0
        _ = f.session.nextBeat() // beat 1

        f.sequencer.currentSamplePosition = f.samplesPerBeat + f.samplesPerBeat / 2

        f.session.evaluatePlaybackPosition()

        #expect(f.session.cyclesInCurrentTrial == 1) // beat 0 missed

        f.session.stop()
    }

    @Test("hit beat is not double-counted as miss by tracking")
    func hitBeatNotDoubleCounted() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()
        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition + 220
        f.session.handleTap()

        #expect(f.session.cyclesInCurrentTrial == 1)

        f.sequencer.currentSamplePosition = f.samplesPerBeat + f.samplesPerBeat / 2
        f.session.evaluatePlaybackPosition()

        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }

    @Test("tracking updates currentBeatPosition and gapPositionInCurrentBeat")
    func trackingUpdatesObservableState() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.third]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat() // beat 0: gap at .third

        // Advance to position .third within beat 0
        f.sequencer.currentSamplePosition = f.samplesPerSubdivision * 2 + f.samplesPerSubdivision / 2

        f.session.evaluatePlaybackPosition()

        #expect(f.session.currentBeatPosition == .third)
        #expect(f.session.gapPositionInCurrentBeat == .third)

        f.session.stop()
    }

    // MARK: - Trial Completion

    @Test("trial completes after 16 beats with hits and notifies observers")
    func trialCompletesAfter16Beats() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        for i in 0..<16 {
            _ = f.session.nextBeat()
            let gapSamplePosition = Int64(i) * f.samplesPerBeat + Int64(3) * f.samplesPerSubdivision
            f.sequencer.currentSamplePosition = gapSamplePosition + 220
            f.session.handleTap()
        }

        #expect(f.observer.completedCallCount == 1)
        #expect(f.session.lastTrialResult != nil)
        #expect(f.session.lastTrialResult?.gapResults.count == 16)
        #expect(f.session.cyclesInCurrentTrial == 0)

        f.session.stop()
    }

    @Test("trial contains correct tempo")
    func trialContainsCorrectTempo() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        for i in 0..<16 {
            _ = f.session.nextBeat()
            let gapSamplePosition = Int64(i) * f.samplesPerBeat + Int64(3) * f.samplesPerSubdivision
            f.sequencer.currentSamplePosition = gapSamplePosition + 220
            f.session.handleTap()
        }

        #expect(f.observer.lastResult?.tempo == TempoBPM(120))

        f.session.stop()
    }

    @Test("trial with missed beats contains only hits")
    func trialWithMissedBeatsContainsOnlyHits() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        for i in 0..<16 {
            _ = f.session.nextBeat()
            if i < 12 {
                let gapSamplePosition = Int64(i) * f.samplesPerBeat + Int64(3) * f.samplesPerSubdivision
                f.sequencer.currentSamplePosition = gapSamplePosition + 220
                f.session.handleTap()
            }
        }

        // Advance past all 16 beats so evaluatePlaybackPosition counts the misses
        f.sequencer.currentSamplePosition = Int64(17) * f.samplesPerBeat
        f.session.evaluatePlaybackPosition()

        let trial = f.observer.lastResult
        #expect(trial != nil)
        #expect(trial?.gapResults.count == 12)

        f.session.stop()
    }

    @Test("trial with no hits is not emitted")
    func trialWithNoHitsIsNotEmitted() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        for _ in 0..<16 {
            _ = f.session.nextBeat()
        }

        f.sequencer.currentSamplePosition = f.samplesPerBeat * 16 + f.samplesPerBeat / 2
        f.session.evaluatePlaybackPosition()

        #expect(f.observer.completedCallCount == 0)
        #expect(f.session.lastTrialResult == nil)
        #expect(f.session.cyclesInCurrentTrial == 0)

        f.session.stop()
    }

    @Test("multiple consecutive trials work correctly")
    func multipleConsecutiveTrialsWorkCorrectly() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        for i in 0..<32 {
            _ = f.session.nextBeat()
            let gapSamplePosition = Int64(i) * f.samplesPerBeat + Int64(3) * f.samplesPerSubdivision
            f.sequencer.currentSamplePosition = gapSamplePosition + 220
            f.session.handleTap()
        }

        #expect(f.observer.completedCallCount == 2)
        #expect(f.observer.results.count == 2)

        f.session.stop()
    }

    // MARK: - BeatProvider Conformance

    @Test("session provides itself as beat provider to sequencer")
    func sessionProvidesItselfAsBeatProvider() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings())
        await f.sequencer.waitForStart()

        #expect(f.sequencer.lastBeatProvider is ContinuousRhythmMatchingSession)

        f.session.stop()
    }

    // MARK: - Auditory Tap Feedback

    @Test("tap within window plays immediate note on beat sequencer")
    func tapWithinWindowPlaysImmediateNote() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition + 220
        f.session.handleTap()

        #expect(f.sequencer.playImmediateNoteCallCount == 1)

        f.session.stop()
    }

    @Test("tap at beat one plays accent velocity, other positions play normal velocity")
    func tapVelocityMatchesGapPosition() async throws {
        let f = makeSession()

        // Test accent velocity for gap at .first
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.first]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()
        let gapSamplePositionFirst = Int64(0) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePositionFirst + 220
        f.session.handleTap()

        #expect(f.sequencer.lastPlayImmediateNoteVelocity == RhythmVelocity.accent)

        f.session.stop()
        f.sequencer.reset()
        f.sequencer.samplesPerBeat = 22050

        // Test normal velocity for gap at .fourth
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()
        let gapSamplePositionFourth = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePositionFourth + 220
        f.session.handleTap()

        #expect(f.sequencer.lastPlayImmediateNoteVelocity == RhythmVelocity.normal)

        f.session.stop()
    }

    @Test("tap outside window does not play immediate note")
    func tapOutsideWindowDoesNotPlayNote() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition + f.samplesPerSubdivision
        f.session.handleTap()

        #expect(f.sequencer.playImmediateNoteCallCount == 0)

        f.session.stop()
    }

    // MARK: - Timing Feedback

    @Test("tap within window exposes signed offset in milliseconds")
    func tapExposesOffsetMs() async throws {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition + 441
        f.session.handleTap()

        let offsetMs = try #require(f.session.lastHitOffsetMs)
        #expect(abs(offsetMs - 10.0) < 0.1)

        f.session.stop()
    }

    @Test("early tap produces negative offset milliseconds")
    func earlyTapProducesNegativeOffsetMs() async throws {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition - 441
        f.session.handleTap()

        let offsetMs = try #require(f.session.lastHitOffsetMs)
        #expect(abs(offsetMs - (-10.0)) < 0.1)

        f.session.stop()
    }

    @Test("stop clears lastHitOffsetMs")
    func stopClearsOffsetMs() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()
        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition + 220
        f.session.handleTap()

        #expect(f.session.lastHitOffsetMs != nil)

        f.session.stop()
        #expect(f.session.lastHitOffsetMs == nil)
    }

    @Test("playImmediateNote error does not crash session")
    func playImmediateNoteErrorDoesNotCrashSession() async {
        let f = makeSession()
        f.sequencer.shouldThrowOnPlayImmediateNote = true
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition + 220
        f.session.handleTap()

        #expect(f.session.isRunning)
        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }

    // MARK: - MIDI Input

    @Test("MIDI noteOn within evaluation window records a hit with correct offset")
    func midiNoteOnWithinWindowRecordsHit() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        let tapSamplePosition = gapSamplePosition + 441

        f.sequencer.samplePositionForHostTimeOverride = tapSamplePosition
        f.sequencer.currentSamplePosition = tapSamplePosition

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await waitForCondition { f.session.cyclesInCurrentTrial == 1 }

        let offsetMs = try #require(f.session.lastHitOffsetMs)
        #expect(abs(offsetMs - 10.0) < 0.1)

        f.session.stop()
    }

    @Test("MIDI noteOn within evaluation window triggers playImmediateNote with correct velocity")
    func midiNoteOnTriggersPlayImmediateNote() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.samplePositionForHostTimeOverride = gapSamplePosition + 220
        f.sequencer.currentSamplePosition = gapSamplePosition + 220

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await waitForCondition { f.sequencer.playImmediateNoteCallCount == 1 }

        #expect(f.sequencer.lastPlayImmediateNoteVelocity == RhythmVelocity.normal)

        f.session.stop()
    }

    @Test("MIDI noteOn within evaluation window shows visual feedback")
    func midiNoteOnShowsVisualFeedback() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.samplePositionForHostTimeOverride = gapSamplePosition + 220
        f.sequencer.currentSamplePosition = gapSamplePosition + 220

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await waitForCondition { f.session.showFeedback }

        #expect(f.session.lastHitOffsetMs != nil)

        f.session.stop()
    }

    @Test("MIDI noteOn outside evaluation window is silently ignored")
    func midiNoteOnOutsideWindowIsIgnored() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        let farPosition = gapSamplePosition + f.samplesPerSubdivision
        f.sequencer.samplePositionForHostTimeOverride = farPosition
        f.sequencer.currentSamplePosition = farPosition

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await Task.sleep(for: .milliseconds(100))

        #expect(f.session.cyclesInCurrentTrial == 0)
        #expect(f.sequencer.playImmediateNoteCallCount == 0)
        #expect(f.session.showFeedback == false)

        f.session.stop()
    }

    @Test("MIDI noteOn in already-hit beat is ignored (double-tap prevention)")
    func midiNoteOnDoubleTapPrevention() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.samplePositionForHostTimeOverride = gapSamplePosition + 220
        f.sequencer.currentSamplePosition = gapSamplePosition + 220

        f.session.handleTap()
        #expect(f.session.cyclesInCurrentTrial == 1)

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await Task.sleep(for: .milliseconds(100))

        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }

    @Test("MIDI noteOff and pitchBend events are ignored")
    func midiNoteOffAndPitchBendIgnored() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.samplePositionForHostTimeOverride = gapSamplePosition + 220
        f.sequencer.currentSamplePosition = gapSamplePosition + 220

        f.midiInput.send(.noteOff(note: MIDINote(60), velocity: MIDIVelocity(1), timestamp: 12345))
        f.midiInput.send(.pitchBend(value: PitchBendValue(8192), channel: MIDIChannel(0), timestamp: 12345))

        try await Task.sleep(for: .milliseconds(100))

        #expect(f.session.cyclesInCurrentTrial == 0)
        #expect(f.sequencer.playImmediateNoteCallCount == 0)

        f.session.stop()
    }

    @Test("session with nil midiInput works identically to before")
    func sessionWithNilMidiInputWorksIdentically() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition + 220
        f.session.handleTap()

        #expect(f.session.cyclesInCurrentTrial == 1)
        #expect(f.sequencer.playImmediateNoteCallCount == 1)

        f.session.stop()
    }

    @Test("MIDI tap uses converted sample position, not current position")
    func midiTapUsesConvertedSamplePosition() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()

        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.samplePositionForHostTimeOverride = gapSamplePosition + 220
        f.sequencer.currentSamplePosition = gapSamplePosition + f.samplesPerSubdivision

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await waitForCondition { f.session.cyclesInCurrentTrial == 1 }

        f.session.stop()
    }

    @Test("MIDI listening task is cancelled when stop is called")
    func midiListeningCancelledOnStop() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        f.session.stop()

        _ = f.session.nextBeat()
        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.samplePositionForHostTimeOverride = gapSamplePosition + 220
        f.sequencer.currentSamplePosition = gapSamplePosition + 220

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await Task.sleep(for: .milliseconds(100))

        #expect(f.session.cyclesInCurrentTrial == 0)
        #expect(f.session.isRunning == false)
    }

    @Test("MIDI noteOn while session is not running is ignored")
    func midiNoteOnWhileNotRunningIsIgnored() async throws {
        let f = makeSessionWithMIDI()

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await Task.sleep(for: .milliseconds(100))

        #expect(f.session.isRunning == false)
        #expect(f.session.cyclesInCurrentTrial == 0)
    }

    @Test("trial completion with mix of screen taps and MIDI taps produces correct aggregation")
    func mixedScreenAndMidiTapsProduceCorrectTrial() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        for i in 0..<16 {
            _ = f.session.nextBeat()
            let gapSamplePosition = Int64(i) * f.samplesPerBeat + Int64(3) * f.samplesPerSubdivision
            let tapPosition = gapSamplePosition + 220

            f.sequencer.samplePositionForHostTimeOverride = tapPosition
            f.sequencer.currentSamplePosition = tapPosition

            if i % 2 == 0 {
                f.session.handleTap()
            } else {
                f.session.handleTap(atSamplePosition: tapPosition)
            }
        }

        #expect(f.observer.completedCallCount == 1)
        #expect(f.observer.lastResult?.gapResults.count == 16)
        #expect(f.observer.lastResult?.tempo == TempoBPM(120))

        f.session.stop()
    }

    // MARK: - Actor Isolation Tests

    @Test("observable state from handleTap is readable on MainActor without await")
    func stateUpdatesOnMainActor() async throws {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextBeat()
        let gapSamplePosition = Int64(3) * f.samplesPerSubdivision
        f.sequencer.currentSamplePosition = gapSamplePosition
        f.session.handleTap(atSamplePosition: gapSamplePosition)

        MainActor.assertIsolated()
        #expect(f.session.isRunning)
        #expect(f.session.showFeedback)
        #expect(f.session.lastHitOffsetMs != nil)
        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }
}
#endif
