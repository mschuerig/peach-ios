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
    }

    private func makeSession() -> Fixture {
        let sequencer = MockStepSequencer()
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

    // MARK: - Initial State

    @Test("starts in idle state")
    func startsInIdleState() async {
        let f = makeSession()
        #expect(f.session.isIdle)
        #expect(!f.session.isRunning)
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
        f.session.start(settings: f.defaultSettings())
        await f.sequencer.waitForStart()

        // Generate some cycles but not enough for a trial
        for _ in 0..<5 {
            _ = f.session.nextCycle()
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

    @Test("nextCycle updates currentGapPosition")
    func nextCycleUpdatesCurrentGapPosition() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.third]))
        await f.sequencer.waitForStart()

        _ = f.session.nextCycle()

        #expect(f.session.currentGapPosition == .third)

        f.session.stop()
    }

    // MARK: - Missed Gap Detection

    @Test("missed gap is recorded when next cycle starts without tap")
    func missedGapRecordedWhenNextCycleStartsWithoutTap() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // First cycle - no tap
        _ = f.session.nextCycle()
        // Second cycle - triggers miss recording for first cycle
        _ = f.session.nextCycle()

        #expect(f.session.cyclesInCurrentTrial == 1)

        f.session.stop()
    }

    // MARK: - Trial Completion

    @Test("trial completes after 16 cycles and notifies observers")
    func trialCompletesAfter16CyclesAndNotifiesObservers() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Generate 16 cycles (all misses)
        // nextCycle records the miss from the previous cycle, so we need 17 calls
        // Cycle 1: no previous, so no miss recorded
        // Cycles 2-17: each records the miss from the previous cycle
        for _ in 0..<17 {
            _ = f.session.nextCycle()
        }

        #expect(f.observer.completedCallCount == 1)
        #expect(f.session.lastTrialResult != nil)
        #expect(f.session.lastTrialResult?.hitRate == 0.0)
        #expect(f.session.lastTrialResult?.gapResults.count == 16)
        #expect(f.session.cyclesInCurrentTrial == 0)

        f.session.stop()
    }

    @Test("trial aggregation computes correct statistics")
    func trialAggregationComputesCorrectStatistics() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // All misses trial
        for _ in 0..<17 {
            _ = f.session.nextCycle()
        }

        let trial = f.observer.lastResult
        #expect(trial != nil)
        #expect(trial?.tempo == TempoBPM(120))
        #expect(trial?.hitRate == 0.0)
        #expect(trial?.meanOffsetMs == 0.0)

        f.session.stop()
    }

    @Test("multiple consecutive trials work correctly")
    func multipleConsecutiveTrialsWorkCorrectly() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings(enabledGapPositions: [.fourth]))
        await f.sequencer.waitForStart()

        // Two complete trials (all misses)
        // First trial: 17 nextCycle calls (1 + 16 that record misses)
        // Second trial: 16 more nextCycle calls
        for _ in 0..<33 {
            _ = f.session.nextCycle()
        }

        #expect(f.observer.completedCallCount == 2)
        #expect(f.observer.results.count == 2)

        f.session.stop()
    }

    // MARK: - Interruption Handling

    @Test("audio interruption stops session and discards incomplete trial")
    func audioInterruptionStopsSession() async {
        let f = makeSession()
        f.session.start(settings: f.defaultSettings())
        await f.sequencer.waitForStart()

        // Generate some cycles
        for _ in 0..<5 {
            _ = f.session.nextCycle()
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
}
