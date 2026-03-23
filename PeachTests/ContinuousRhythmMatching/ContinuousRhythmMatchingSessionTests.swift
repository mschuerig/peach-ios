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
        var mockTime: Double = 1000.0

        func defaultSettings(
            tempo: TempoBPM = TempoBPM(120),
            enabledGapPositions: Set<StepPosition> = [.fourth]
        ) -> ContinuousRhythmMatchingSettings {
            ContinuousRhythmMatchingSettings(
                tempo: tempo,
                enabledGapPositions: enabledGapPositions
            )
        }

        /// Sixteenth note duration at 120 BPM = 125ms
        var sixteenthDuration: Double { 60.0 / (120.0 * 4.0) }
        /// Cycle duration at 120 BPM = 500ms
        var cycleDuration: Double { sixteenthDuration * 4.0 }
    }

    private func makeSession() -> Fixture {
        let sequencer = MockStepSequencer()
        let observer = MockContinuousRhythmMatchingObserver()
        let notificationCenter = NotificationCenter()
        var fixture = Fixture(
            session: ContinuousRhythmMatchingSession(stepSequencer: sequencer),
            sequencer: sequencer,
            observer: observer,
            notificationCenter: notificationCenter
        )

        var mockTime = fixture.mockTime
        let session = ContinuousRhythmMatchingSession(
            stepSequencer: sequencer,
            observers: [observer],
            notificationCenter: notificationCenter,
            currentTime: { mockTime }
        )
        fixture = Fixture(
            session: session,
            sequencer: sequencer,
            observer: observer,
            notificationCenter: notificationCenter,
            mockTime: mockTime
        )

        return fixture
    }

    /// Creates a fixture with a controllable time closure. Returns the fixture and a setter for mock time.
    private func makeTimedSession() -> (fixture: Fixture, setTime: (Double) -> Void) {
        let sequencer = MockStepSequencer()
        let observer = MockContinuousRhythmMatchingObserver()
        let notificationCenter = NotificationCenter()

        var mockTime = 1000.0
        let session = ContinuousRhythmMatchingSession(
            stepSequencer: sequencer,
            observers: [observer],
            notificationCenter: notificationCenter,
            currentTime: { mockTime }
        )
        let fixture = Fixture(
            session: session,
            sequencer: sequencer,
            observer: observer,
            notificationCenter: notificationCenter,
            mockTime: mockTime
        )

        return (fixture, { newTime in mockTime = newTime })
    }

    // MARK: - Initial State

    @Test("starts in idle state")
    func startsInIdleState() async {
        let (f, _) = makeTimedSession()
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
        let (f, _) = makeTimedSession()
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
        let (f, _) = makeTimedSession()
        f.session.start(settings: f.defaultSettings())
        await f.sequencer.waitForStart()

        f.session.start(settings: f.defaultSettings())

        #expect(f.sequencer.startCallCount == 1)

        f.session.stop()
    }

    // MARK: - Stop

    @Test("stop transitions to idle")
    func stopTransitionsToIdle() async {
        let (f, _) = makeTimedSession()
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
        let (f, _) = makeTimedSession()
        f.session.stop()
        #expect(f.session.isIdle)
    }

    @Test("stop discards incomplete trial")
    func stopDiscardsIncompleteTrial() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Populate gap positions and record a few hits
        for i in 0..<5 {
            _ = f.session.nextCycle()
            let gapTime = f.mockTime + Double(i * 4 + 3) * f.sixteenthDuration
            setTime(gapTime + 0.005)
            f.session.handleTap()
        }

        f.session.stop()

        #expect(f.observer.completedCallCount == 0)
        #expect(f.session.lastTrialResult == nil)
    }

    // MARK: - Gap Selection (nextCycle)

    @Test("nextCycle selects from enabled positions")
    func nextCycleSelectsFromEnabledPositions() async {
        let (f, _) = makeTimedSession()
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
        let (f, _) = makeTimedSession()
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
        let (f, _) = makeTimedSession()
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
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Populate gap positions
        _ = f.session.nextCycle() // cycle 0: gap at .fourth

        // Tap 10ms after the gap time
        // Gap time for cycle 0 at .fourth = startTime + (0 * 4 + 3) * sixteenthDuration
        let gapTime = f.mockTime + Double(3) * f.sixteenthDuration
        setTime(gapTime + 0.010) // 10ms late

        f.session.handleTap()

        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }

    @Test("tap outside evaluation window is ignored")
    func tapOutsideWindowIsIgnored() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle() // cycle 0: gap at .fourth

        // Tap way outside the window (2 seconds late)
        setTime(f.mockTime + 2.0)

        f.session.handleTap()

        #expect(f.session.cyclesInCurrentTrial == 0)

        f.session.stop()
    }

    @Test("double tap in same cycle is ignored")
    func doubleTapInSameCycleIsIgnored() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle() // cycle 0: gap at .fourth

        let gapTime = f.mockTime + Double(3) * f.sixteenthDuration
        setTime(gapTime + 0.005)

        f.session.handleTap()
        f.session.handleTap() // second tap

        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }

    // MARK: - Miss Detection via Tracking

    @Test("missed gap is recorded when cycle advances without tap")
    func missedGapRecordedWhenCycleAdvances() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle() // cycle 0
        _ = f.session.nextCycle() // cycle 1

        // Advance time past cycle 0 into cycle 1
        setTime(f.mockTime + f.cycleDuration * 1.5)

        f.session.evaluatePlaybackPosition()

        #expect(f.session.cyclesInCurrentTrial == 1) // cycle 0 missed

        f.session.stop()
    }

    @Test("hit cycle is not double-counted as miss by tracking")
    func hitCycleNotDoubleCounted() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle() // cycle 0: gap at .fourth
        _ = f.session.nextCycle() // cycle 1

        // Tap during cycle 0's gap window
        let gapTime = f.mockTime + Double(3) * f.sixteenthDuration
        setTime(gapTime + 0.005)
        f.session.handleTap()

        #expect(f.session.cyclesInCurrentTrial == 1) // hit recorded

        // Now advance time past cycle 0
        setTime(f.mockTime + f.cycleDuration * 1.5)
        f.session.evaluatePlaybackPosition()

        // Should still be 1 — cycle 0 was hit, not double-counted
        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }

    @Test("tracking updates currentStep and currentGapPosition")
    func trackingUpdatesObservableState() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.third]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle() // cycle 0: gap at .third

        // Advance to step 2 (third sixteenth) within cycle 0
        setTime(f.mockTime + f.sixteenthDuration * 2.5)

        f.session.evaluatePlaybackPosition()

        #expect(f.session.currentStep == .third)
        #expect(f.session.currentGapPosition == .third)

        f.session.stop()
    }

    // MARK: - Trial Completion

    @Test("trial completes after 16 cycles with hits and notifies observers")
    func trialCompletesAfter16Cycles() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Populate 16 cycles and hit all of them
        for i in 0..<16 {
            _ = f.session.nextCycle()
            let gapTime = f.mockTime + Double(i * 4 + 3) * f.sixteenthDuration
            setTime(gapTime + 0.005)
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
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        for i in 0..<16 {
            _ = f.session.nextCycle()
            let gapTime = f.mockTime + Double(i * 4 + 3) * f.sixteenthDuration
            setTime(gapTime + 0.005)
            f.session.handleTap()
        }

        #expect(f.observer.lastResult?.tempo == TempoBPM(120))

        f.session.stop()
    }

    @Test("trial with missed cycles contains only hits")
    func trialWithMissedCyclesContainsOnlyHits() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Populate 16 cycles, hit only the first 12
        for i in 0..<16 {
            _ = f.session.nextCycle()
            if i < 12 {
                let gapTime = f.mockTime + Double(i * 4 + 3) * f.sixteenthDuration
                setTime(gapTime + 0.005)
                f.session.handleTap()
            }
        }

        // Advance time past all 16 cycles so evaluatePlaybackPosition counts the misses
        setTime(f.mockTime + 17.0 * f.cycleDuration)
        f.session.evaluatePlaybackPosition()

        let trial = f.observer.lastResult
        #expect(trial != nil)
        #expect(trial?.gapResults.count == 12)

        f.session.stop()
    }

    @Test("trial with no hits is not emitted")
    func trialWithNoHitsIsNotEmitted() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Populate 16 cycles but don't hit any
        for _ in 0..<16 {
            _ = f.session.nextCycle()
        }

        // Advance time to mid-cycle 16 — exactly 16 completed cycles (0–15) are evaluated
        setTime(f.mockTime + 16.5 * f.cycleDuration)
        f.session.evaluatePlaybackPosition()

        #expect(f.observer.completedCallCount == 0)
        #expect(f.session.lastTrialResult == nil)
        #expect(f.session.cyclesInCurrentTrial == 0)

        f.session.stop()
    }

    @Test("multiple consecutive trials work correctly")
    func multipleConsecutiveTrialsWorkCorrectly() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Two complete trials, hitting every gap
        for i in 0..<32 {
            _ = f.session.nextCycle()
            let gapTime = f.mockTime + Double(i * 4 + 3) * f.sixteenthDuration
            setTime(gapTime + 0.005)
            f.session.handleTap()
        }

        #expect(f.observer.completedCallCount == 2)
        #expect(f.observer.results.count == 2)

        f.session.stop()
    }

    // MARK: - Interruption Handling

    @Test("audio interruption stops session and discards incomplete trial")
    func audioInterruptionStopsSession() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Record some hits but not enough for a trial
        for i in 0..<5 {
            _ = f.session.nextCycle()
            let gapTime = f.mockTime + Double(i * 4 + 3) * f.sixteenthDuration
            setTime(gapTime + 0.005)
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
        let (f, _) = makeTimedSession()
        f.session.start(settings: f.defaultSettings())
        await f.sequencer.waitForStart()

        #expect(f.sequencer.lastStepProvider is ContinuousRhythmMatchingSession)

        f.session.stop()
    }

    // MARK: - Auditory Tap Feedback

    @Test("tap within window plays immediate note on step sequencer")
    func tapWithinWindowPlaysImmediateNote() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()

        let gapTime = f.mockTime + Double(3) * f.sixteenthDuration
        setTime(gapTime + 0.005)
        f.session.handleTap()

        #expect(f.sequencer.playImmediateNoteCallCount == 1)

        f.session.stop()
    }

    @Test("tap at beat one plays accent velocity, other positions play normal velocity")
    func tapVelocityMatchesGapPosition() async {
        let (f, setTime) = makeTimedSession()

        // Test accent velocity for gap at .first
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.first]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()
        let gapTimeFirst = f.mockTime + Double(0) * f.sixteenthDuration
        setTime(gapTimeFirst + 0.005)
        f.session.handleTap()

        #expect(f.sequencer.lastPlayImmediateNoteVelocity == StepVelocity.accent)

        f.session.stop()
        f.sequencer.reset()

        // Test normal velocity for gap at .fourth
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()
        let gapTimeFourth = f.mockTime + Double(3) * f.sixteenthDuration
        setTime(gapTimeFourth + 0.005)
        f.session.handleTap()

        #expect(f.sequencer.lastPlayImmediateNoteVelocity == StepVelocity.normal)

        f.session.stop()
    }

    @Test("tap outside window does not play immediate note")
    func tapOutsideWindowDoesNotPlayNote() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()

        // Tap way outside the window
        setTime(f.mockTime + 2.0)
        f.session.handleTap()

        #expect(f.sequencer.playImmediateNoteCallCount == 0)

        f.session.stop()
    }

    // MARK: - Timing Feedback

    @Test("tap within window exposes signed offset in milliseconds")
    func tapExposesOffsetMs() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()

        // Tap 10ms after the gap time → positive (late) offset
        let gapTime = f.mockTime + Double(3) * f.sixteenthDuration
        setTime(gapTime + 0.010)
        f.session.handleTap()

        #expect(f.session.lastHitOffsetMs != nil)
        let offsetMs = f.session.lastHitOffsetMs!
        #expect(abs(offsetMs - 10.0) < 0.1)

        f.session.stop()
    }

    @Test("early tap produces negative offset milliseconds")
    func earlyTapProducesNegativeOffsetMs() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()

        // Tap 10ms before the gap time → negative (early) offset
        let gapTime = f.mockTime + Double(3) * f.sixteenthDuration
        setTime(gapTime - 0.010)
        f.session.handleTap()

        #expect(f.session.lastHitOffsetMs != nil)
        let offsetMs = f.session.lastHitOffsetMs!
        #expect(abs(offsetMs - (-10.0)) < 0.1)

        f.session.stop()
    }

    @Test("stop clears lastHitOffsetMs")
    func stopClearsOffsetMs() async {
        let (f, setTime) = makeTimedSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()
        let gapTime = f.mockTime + Double(3) * f.sixteenthDuration
        setTime(gapTime + 0.005)
        f.session.handleTap()

        #expect(f.session.lastHitOffsetMs != nil)

        f.session.stop()
        #expect(f.session.lastHitOffsetMs == nil)
    }

    @Test("playImmediateNote error does not crash session")
    func playImmediateNoteErrorDoesNotCrashSession() async {
        let (f, setTime) = makeTimedSession()
        f.sequencer.shouldThrowOnPlayImmediateNote = true
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()

        let gapTime = f.mockTime + Double(3) * f.sixteenthDuration
        setTime(gapTime + 0.005)
        f.session.handleTap()

        // Session should still be running and the hit should still be recorded
        #expect(f.session.isRunning)
        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }
}
