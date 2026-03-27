import AVFoundation
import Foundation
import Testing
@testable import Peach

@Suite("ContinuousRhythmMatchingSession")
struct ContinuousRhythmMatchingSessionTests {

    // MARK: - Test Fixture

    private struct Fixture {
        let session: ContinuousRhythmMatchingSession
        let sequencer: MockStepSequencer
        let observer: MockContinuousRhythmMatchingObserver
        let notificationCenter: NotificationCenter

        func defaultSettings(
            tempo: TempoBPM = TempoBPM(120),
            enabledGapPositions: Set<StepPosition> = [.fourth]
        ) -> ContinuousRhythmMatchingSettings {
            ContinuousRhythmMatchingSettings(
                tempo: tempo,
                enabledGapPositions: enabledGapPositions
            )
        }

        /// samplesPerStep at 120 BPM / 44100 Hz = Int64(44100.0 * 0.125) = 5512
        var samplesPerStep: Int64 { sequencer.samplesPerStep }
        /// samplesPerCycle = samplesPerStep * 4 = 22050
        var samplesPerCycle: Int64 { sequencer.samplesPerCycle }
    }

    private struct MIDIFixture {
        let session: ContinuousRhythmMatchingSession
        let sequencer: MockStepSequencer
        let observer: MockContinuousRhythmMatchingObserver
        let midiInput: MockMIDIInput
        let notificationCenter: NotificationCenter

        func defaultSettings(
            tempo: TempoBPM = TempoBPM(120),
            enabledGapPositions: Set<StepPosition> = [.fourth]
        ) -> ContinuousRhythmMatchingSettings {
            ContinuousRhythmMatchingSettings(
                tempo: tempo,
                enabledGapPositions: enabledGapPositions
            )
        }

        var samplesPerStep: Int64 { sequencer.samplesPerStep }
        var samplesPerCycle: Int64 { sequencer.samplesPerCycle }
    }

    private func makeSession() -> Fixture {
        let sequencer = MockStepSequencer()
        // Set timing constants matching 120 BPM at 44100 Hz
        sequencer.samplesPerStep = 5512
        sequencer.samplesPerCycle = 22050
        sequencer.sampleRate = .standard44100

        let observer = MockContinuousRhythmMatchingObserver()
        let notificationCenter = NotificationCenter()

        let session = ContinuousRhythmMatchingSession(
            stepSequencer: sequencer,
            observers: [observer],
            notificationCenter: notificationCenter
        )

        return Fixture(
            session: session,
            sequencer: sequencer,
            observer: observer,
            notificationCenter: notificationCenter
        )
    }

    private func makeSessionWithMIDI() -> MIDIFixture {
        let sequencer = MockStepSequencer()
        sequencer.samplesPerStep = 5512
        sequencer.samplesPerCycle = 22050
        sequencer.sampleRate = .standard44100

        let observer = MockContinuousRhythmMatchingObserver()
        let midiInput = MockMIDIInput()
        let notificationCenter = NotificationCenter()

        let session = ContinuousRhythmMatchingSession(
            stepSequencer: sequencer,
            observers: [observer],
            midiInput: midiInput,
            notificationCenter: notificationCenter
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
        #expect(!f.session.isRunning)
        #expect(f.session.currentStep == nil)
        #expect(f.session.currentGapPosition == nil)
        #expect(f.session.cyclesInCurrentTrial == 0)
        #expect(f.session.lastTrialResult == nil)
    }

    // MARK: - Start

    @Test("start begins step sequencer")
    func startBeginsStepSequencer() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings())

        await f.sequencer.waitForStart()

        #expect(f.session.isRunning)
        #expect(!f.session.isIdle)
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
        #expect(!f.session.isRunning)
        #expect(f.session.currentStep == nil)
        #expect(f.session.currentGapPosition == nil)
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
            _ = f.session.nextCycle()
            // Gap at .fourth = step index 3 within cycle i
            let gapSamplePosition = Int64(i * 4 + 3) * f.samplesPerStep
            f.sequencer.currentSamplePosition = gapSamplePosition + 220 // ~5ms late at 44100 Hz
            f.session.handleTap()
        }

        f.session.stop()

        #expect(f.observer.completedCallCount == 0)
        #expect(f.session.lastTrialResult == nil)
    }

    // MARK: - Gap Selection (nextCycle)

    @Test("nextCycle selects from enabled positions")
    func nextCycleSelectsFromEnabledPositions() async {
        let f = makeSession()
        let enabledPositions: Set<StepPosition> = [.second, .third]
        f.session.start(settings: f.defaultSettings(enabledGapPositions: enabledPositions))
        await f.sequencer.waitForStart()

        for _ in 0..<20 {
            let cycle = f.session.nextCycle()
            #expect(enabledPositions.contains(cycle.gapPosition))
        }

        f.session.stop()
    }

    @Test("nextCycle with single enabled position always returns it")
    func nextCycleWithSinglePositionAlwaysReturnsIt() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.second]))
        await f.sequencer.waitForStart()

        for _ in 0..<10 {
            let cycle = f.session.nextCycle()
            #expect(cycle.gapPosition == .second)
        }

        f.session.stop()
    }

    @Test("nextCycle is side-effect-free — does not record gap results")
    func nextCycleIsSideEffectFree() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings())
        await f.sequencer.waitForStart()

        for _ in 0..<20 {
            _ = f.session.nextCycle()
        }

        #expect(f.session.cyclesInCurrentTrial == 0)
        #expect(f.observer.completedCallCount == 0)

        f.session.stop()
    }

    // MARK: - Tap Evaluation

    @Test("tap inside evaluation window records hit with correct offset")
    func tapInsideWindowRecordsHit() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle() // cycle 0: gap at .fourth

        // Gap at .fourth in cycle 0: sample position = (0*4 + 3) * samplesPerStep = 3 * 5512 = 16536
        let gapSamplePosition = Int64(3) * f.samplesPerStep
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

        _ = f.session.nextCycle() // cycle 0: gap at .fourth

        // Tap one full step away from the gap — within cycle 0 but outside the half-step window
        let gapSamplePosition = Int64(3) * f.samplesPerStep
        f.sequencer.currentSamplePosition = gapSamplePosition + f.samplesPerStep

        f.session.handleTap()

        #expect(f.session.cyclesInCurrentTrial == 0)

        f.session.stop()
    }

    @Test("double tap in same cycle is ignored")
    func doubleTapInSameCycleIsIgnored() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle() // cycle 0: gap at .fourth

        let gapSamplePosition = Int64(3) * f.samplesPerStep
        f.sequencer.currentSamplePosition = gapSamplePosition + 220

        f.session.handleTap()
        f.session.handleTap() // second tap

        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }

    // MARK: - Miss Detection via Tracking

    @Test("missed gap is recorded when cycle advances without tap")
    func missedGapRecordedWhenCycleAdvances() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle() // cycle 0
        _ = f.session.nextCycle() // cycle 1

        // Advance sample position past cycle 0 into mid-cycle 1
        f.sequencer.currentSamplePosition = f.samplesPerCycle + f.samplesPerCycle / 2

        f.session.evaluatePlaybackPosition()

        #expect(f.session.cyclesInCurrentTrial == 1) // cycle 0 missed

        f.session.stop()
    }

    @Test("hit cycle is not double-counted as miss by tracking")
    func hitCycleNotDoubleCounted() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle() // cycle 0: gap at .fourth
        _ = f.session.nextCycle() // cycle 1

        // Tap during cycle 0's gap window
        let gapSamplePosition = Int64(3) * f.samplesPerStep
        f.sequencer.currentSamplePosition = gapSamplePosition + 220
        f.session.handleTap()

        #expect(f.session.cyclesInCurrentTrial == 1) // hit recorded

        // Now advance time past cycle 0
        f.sequencer.currentSamplePosition = f.samplesPerCycle + f.samplesPerCycle / 2
        f.session.evaluatePlaybackPosition()

        // Should still be 1 — cycle 0 was hit, not double-counted
        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }

    @Test("tracking updates currentStep and currentGapPosition")
    func trackingUpdatesObservableState() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.third]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle() // cycle 0: gap at .third

        // Advance to step 2 (third sixteenth) within cycle 0
        f.sequencer.currentSamplePosition = f.samplesPerStep * 2 + f.samplesPerStep / 2

        f.session.evaluatePlaybackPosition()

        #expect(f.session.currentStep == .third)
        #expect(f.session.currentGapPosition == .third)

        f.session.stop()
    }

    // MARK: - Trial Completion

    @Test("trial completes after 16 cycles with hits and notifies observers")
    func trialCompletesAfter16Cycles() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Populate 16 cycles and hit all of them
        for i in 0..<16 {
            _ = f.session.nextCycle()
            let gapSamplePosition = Int64(i * 4 + 3) * f.samplesPerStep
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
            _ = f.session.nextCycle()
            let gapSamplePosition = Int64(i * 4 + 3) * f.samplesPerStep
            f.sequencer.currentSamplePosition = gapSamplePosition + 220
            f.session.handleTap()
        }

        #expect(f.observer.lastResult?.tempo == TempoBPM(120))

        f.session.stop()
    }

    @Test("trial with missed cycles contains only hits")
    func trialWithMissedCyclesContainsOnlyHits() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Populate 16 cycles, hit only the first 12
        for i in 0..<16 {
            _ = f.session.nextCycle()
            if i < 12 {
                let gapSamplePosition = Int64(i * 4 + 3) * f.samplesPerStep
                f.sequencer.currentSamplePosition = gapSamplePosition + 220
                f.session.handleTap()
            }
        }

        // Advance sample position past all 16 cycles so evaluatePlaybackPosition counts the misses
        f.sequencer.currentSamplePosition = Int64(17) * f.samplesPerCycle
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

        // Populate 16 cycles but don't hit any
        for _ in 0..<16 {
            _ = f.session.nextCycle()
        }

        // Advance sample position to mid-cycle 16
        f.sequencer.currentSamplePosition = f.samplesPerCycle * 16 + f.samplesPerCycle / 2
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

        // Two complete trials, hitting every gap
        for i in 0..<32 {
            _ = f.session.nextCycle()
            let gapSamplePosition = Int64(i * 4 + 3) * f.samplesPerStep
            f.sequencer.currentSamplePosition = gapSamplePosition + 220
            f.session.handleTap()
        }

        #expect(f.observer.completedCallCount == 2)
        #expect(f.observer.results.count == 2)

        f.session.stop()
    }

    // MARK: - Interruption Handling

    @Test("audio interruption stops session and discards incomplete trial")
    func audioInterruptionStopsSession() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Record some hits but not enough for a trial
        for i in 0..<5 {
            _ = f.session.nextCycle()
            let gapSamplePosition = Int64(i * 4 + 3) * f.samplesPerStep
            f.sequencer.currentSamplePosition = gapSamplePosition + 220
            f.session.handleTap()
        }

        // Simulate audio interruption
        f.notificationCenter.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        // Give the notification a moment to propagate
        try? await Task.sleep(for: .milliseconds(50))

        #expect(f.session.isIdle)
        #expect(f.observer.completedCallCount == 0)
    }

    // MARK: - StepProvider Conformance

    @Test("session provides itself as step provider to sequencer")
    func sessionProvidesItselfAsStepProvider() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings())
        await f.sequencer.waitForStart()

        #expect(f.sequencer.lastStepProvider is ContinuousRhythmMatchingSession)

        f.session.stop()
    }

    // MARK: - Auditory Tap Feedback

    @Test("tap within window plays immediate note on step sequencer")
    func tapWithinWindowPlaysImmediateNote() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()

        let gapSamplePosition = Int64(3) * f.samplesPerStep
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

        _ = f.session.nextCycle()
        let gapSamplePositionFirst = Int64(0) * f.samplesPerStep
        f.sequencer.currentSamplePosition = gapSamplePositionFirst + 220
        f.session.handleTap()

        #expect(f.sequencer.lastPlayImmediateNoteVelocity == StepVelocity.accent)

        f.session.stop()
        f.sequencer.reset()
        f.sequencer.samplesPerStep = 5512
        f.sequencer.samplesPerCycle = 22050

        // Test normal velocity for gap at .fourth
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()
        let gapSamplePositionFourth = Int64(3) * f.samplesPerStep
        f.sequencer.currentSamplePosition = gapSamplePositionFourth + 220
        f.session.handleTap()

        #expect(f.sequencer.lastPlayImmediateNoteVelocity == StepVelocity.normal)

        f.session.stop()
    }

    @Test("tap outside window does not play immediate note")
    func tapOutsideWindowDoesNotPlayNote() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()

        // Tap one full step away from the gap — within cycle 0 but outside the half-step window
        let gapSamplePosition = Int64(3) * f.samplesPerStep
        f.sequencer.currentSamplePosition = gapSamplePosition + f.samplesPerStep
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

        _ = f.session.nextCycle()

        // Tap 441 samples after the gap = 441/44100 = 10ms late
        let gapSamplePosition = Int64(3) * f.samplesPerStep
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

        _ = f.session.nextCycle()

        // Tap 441 samples before the gap = -441/44100 = -10ms early
        let gapSamplePosition = Int64(3) * f.samplesPerStep
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

        _ = f.session.nextCycle()
        let gapSamplePosition = Int64(3) * f.samplesPerStep
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

        _ = f.session.nextCycle()

        let gapSamplePosition = Int64(3) * f.samplesPerStep
        f.sequencer.currentSamplePosition = gapSamplePosition + 220
        f.session.handleTap()

        // Session should still be running and the hit should still be recorded
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

        _ = f.session.nextCycle()

        let gapSamplePosition = Int64(3) * f.samplesPerStep
        let tapSamplePosition = gapSamplePosition + 441 // ~10ms late

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

        _ = f.session.nextCycle()

        let gapSamplePosition = Int64(3) * f.samplesPerStep
        f.sequencer.samplePositionForHostTimeOverride = gapSamplePosition + 220
        f.sequencer.currentSamplePosition = gapSamplePosition + 220

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await waitForCondition { f.sequencer.playImmediateNoteCallCount == 1 }

        #expect(f.sequencer.lastPlayImmediateNoteVelocity == StepVelocity.normal)

        f.session.stop()
    }

    @Test("MIDI noteOn within evaluation window shows visual feedback")
    func midiNoteOnShowsVisualFeedback() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()

        let gapSamplePosition = Int64(3) * f.samplesPerStep
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

        _ = f.session.nextCycle()

        // Position one full step away from gap — outside the half-step window
        let gapSamplePosition = Int64(3) * f.samplesPerStep
        let farPosition = gapSamplePosition + f.samplesPerStep
        f.sequencer.samplePositionForHostTimeOverride = farPosition
        f.sequencer.currentSamplePosition = farPosition

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await Task.sleep(for: .milliseconds(100))

        #expect(f.session.cyclesInCurrentTrial == 0)
        #expect(f.sequencer.playImmediateNoteCallCount == 0)
        #expect(!f.session.showFeedback)

        f.session.stop()
    }

    @Test("MIDI noteOn in already-hit cycle is ignored (double-tap prevention)")
    func midiNoteOnDoubleTapPrevention() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()

        let gapSamplePosition = Int64(3) * f.samplesPerStep
        f.sequencer.samplePositionForHostTimeOverride = gapSamplePosition + 220
        f.sequencer.currentSamplePosition = gapSamplePosition + 220

        // First tap via screen
        f.session.handleTap()
        #expect(f.session.cyclesInCurrentTrial == 1)

        // Second tap via MIDI — should be ignored
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

        _ = f.session.nextCycle()

        let gapSamplePosition = Int64(3) * f.samplesPerStep
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
        let f = makeSession() // no MIDI input
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()

        let gapSamplePosition = Int64(3) * f.samplesPerStep
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

        _ = f.session.nextCycle()

        let gapSamplePosition = Int64(3) * f.samplesPerStep
        // Override returns a position within the window
        f.sequencer.samplePositionForHostTimeOverride = gapSamplePosition + 220
        // But currentSamplePosition is far away — outside the window
        f.sequencer.currentSamplePosition = gapSamplePosition + f.samplesPerStep

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

        // Send MIDI event after stop — should be ignored
        _ = f.session.nextCycle()
        let gapSamplePosition = Int64(3) * f.samplesPerStep
        f.sequencer.samplePositionForHostTimeOverride = gapSamplePosition + 220
        f.sequencer.currentSamplePosition = gapSamplePosition + 220

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await Task.sleep(for: .milliseconds(100))

        #expect(f.session.cyclesInCurrentTrial == 0)
        #expect(!f.session.isRunning)
    }

    @Test("MIDI noteOn while session is not running is ignored")
    func midiNoteOnWhileNotRunningIsIgnored() async throws {
        let f = makeSessionWithMIDI()
        // Do not start the session

        f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

        try await Task.sleep(for: .milliseconds(100))

        #expect(!f.session.isRunning)
        #expect(f.session.cyclesInCurrentTrial == 0)
    }

    @Test("trial completion with mix of screen taps and MIDI taps produces correct aggregation")
    func mixedScreenAndMidiTapsProduceCorrectTrial() async throws {
        let f = makeSessionWithMIDI()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Use screen taps (synchronous handleTap with overridden sample position) for
        // deterministic behavior. Individual MIDI tap tests verify the MIDI → handleTap path;
        // this test verifies correct trial aggregation across 16 cycles.
        for i in 0..<16 {
            _ = f.session.nextCycle()
            let gapSamplePosition = Int64(i * 4 + 3) * f.samplesPerStep
            let tapPosition = gapSamplePosition + 220

            f.sequencer.samplePositionForHostTimeOverride = tapPosition
            f.sequencer.currentSamplePosition = tapPosition

            if i % 2 == 0 {
                // Even cycles: screen tap (no override)
                f.session.handleTap()
            } else {
                // Odd cycles: screen tap with explicit sample position (simulates MIDI path)
                f.session.handleTap(atSamplePosition: tapPosition)
            }
        }

        #expect(f.observer.completedCallCount == 1)
        #expect(f.observer.lastResult?.gapResults.count == 16)
        #expect(f.observer.lastResult?.tempo == TempoBPM(120))

        f.session.stop()
    }
}
