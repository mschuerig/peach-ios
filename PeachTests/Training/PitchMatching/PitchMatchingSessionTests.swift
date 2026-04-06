import Foundation
import Testing
@testable import Peach

// MARK: - Test Helpers

func waitForState(
    _ session: PitchMatchingSession,
    _ expectedState: PitchMatchingSessionState,
    timeout: Duration = .seconds(5)
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

/// Transition session from awaitingSliderTouch to playingTunable with handle assigned
func transitionToPlayingTunable(_ session: PitchMatchingSession) async throws {
    try await waitForState(session, .awaitingSliderTouch)
    session.adjustPitch(0.0)
    try await Task.sleep(for: .milliseconds(50))
}

// MARK: - Factory

let defaultPitchMatchingTestSettings = PitchMatchingSettings(
    referencePitch: Frequency(440.0),
    intervals: [.prime],
    noteDuration: NoteDuration(0.3)
)

func makePitchMatchingSession(
    notificationCenter: NotificationCenter = .default,
    audioInterruptionObserver: AudioInterruptionObserving = NoOpAudioInterruptionObserver(),
    backgroundNotificationName: Notification.Name? = nil,
    foregroundNotificationName: Notification.Name? = nil
) -> (session: PitchMatchingSession, notePlayer: MockNotePlayer, profile: MockTrainingProfile, observer: MockPitchMatchingObserver) {
    let notePlayer = MockNotePlayer()
    let profile = MockTrainingProfile()
    let observer = MockPitchMatchingObserver()
    let session = PitchMatchingSession(
        notePlayer: notePlayer,
        profile: profile,
        observers: [observer],
        notificationCenter: notificationCenter,
        audioInterruptionObserver: audioInterruptionObserver,
        backgroundNotificationName: backgroundNotificationName,
        foregroundNotificationName: foregroundNotificationName
    )
    return (session, notePlayer, profile, observer)
}

// MARK: - Task 1: Skeleton Tests

@Suite("PitchMatchingSession")
struct PitchMatchingSessionTests {

    @Test("starts in idle state")
    func startsInIdleState() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.state == .idle)
    }

    @Test("currentTrial is nil initially")
    func currentTrialNilInitially() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.currentTrial == nil)
    }

    @Test("lastResult is nil initially")
    func lastResultNilInitially() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.lastResult == nil)
    }

    // MARK: - Task 2: Trial Generation Tests

    @Test("trial has note within configured range")
    func trialNoteWithinRange() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(72)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await waitForState(session, .awaitingSliderTouch)

        let trial = try #require(session.currentTrial)
        #expect(trial.referenceNote >= 48)
        #expect(trial.referenceNote <= 72)
    }

    @Test("trial has offset within ±20 cents")
    func trialOffsetWithinRange() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        let trial = try #require(session.currentTrial)
        #expect(trial.initialCentOffset >= -20)
        #expect(trial.initialCentOffset <= 20)
    }

    // MARK: - Task 3: State Transition Tests

    @Test("start transitions to playingReference")
    func startTransitionsToPlayingReference() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = .seconds(5)
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .playingReference)

        #expect(session.state == .playingReference)
    }

    @Test("reference note played at correct frequency")
    func referenceNoteFrequency() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await waitForState(session, .awaitingSliderTouch)

        let trial = try #require(session.currentTrial)
        let expectedFreq = TuningSystem.equalTemperament.frequency(for: trial.referenceNote, referencePitch: .concert440)
        #expect(notePlayer.playHistory.first != nil)
        let firstPlay = notePlayer.playHistory.first!
        #expect(abs(firstPlay.frequency - expectedFreq.rawValue) < 0.01)
    }

    @Test("transitions to awaitingSliderTouch after reference")
    func transitionsToAwaitingSliderTouchAfterReference() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        #expect(session.state == .awaitingSliderTouch)
    }

    @Test("no tunable note played in awaitingSliderTouch")
    func noTunableNoteInAwaitingSliderTouch() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        // Only the reference note (fire-and-forget) should have been played
        // Note: mock's fire-and-forget play internally calls handle-returning play, so playCallCount is 1
        #expect(notePlayer.playCallCount == 1)
        #expect(notePlayer.handleHistory.count == 1)
    }

    @Test("adjustPitch from awaitingSliderTouch transitions to playingTunable and starts note")
    func adjustPitchFromAwaitingSliderTouchStartsNote() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        #expect(notePlayer.playCallCount == 1)
        session.adjustPitch(0.0)
        #expect(session.state == .playingTunable)
        try await Task.sleep(for: .milliseconds(50))

        // Tunable note should now have been played
        #expect(notePlayer.playCallCount == 2)
        #expect(notePlayer.lastHandle != nil)
    }

    @Test("commitPitch from awaitingSliderTouch produces result with initial offset error")
    func commitPitchFromAwaitingSliderTouchProducesResult() async throws {
        let (session, notePlayer, _, observer) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await waitForState(session, .awaitingSliderTouch)

        let trial = try #require(session.currentTrial)
        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        // Slider at 0 means "accept detuned pitch as-is" — error should equal initialCentOffset, not 0
        #expect(abs(result.userCentError.rawValue - trial.initialCentOffset.rawValue) < 0.01)
        // Only reference note played — no tunable note started (would be immediately orphaned)
        #expect(notePlayer.playCallCount == 1)
    }

    @Test("stop from awaitingSliderTouch transitions to idle with no tunable note")
    func stopFromAwaitingSliderTouch() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        session.stop()
        #expect(session.state == .idle)
        #expect(session.currentTrial == nil)
        // Only reference note was played, no tunable note
        #expect(notePlayer.playCallCount == 1)
    }

    @Test("tunable note played at offset frequency")
    func tunableNoteAtOffsetFrequency() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await transitionToPlayingTunable(session)

        let trial = try #require(session.currentTrial)
        let baseFreq = TuningSystem.equalTemperament.frequency(for: trial.referenceNote, referencePitch: .concert440)
        let expectedTunableFreq = baseFreq.rawValue * pow(2.0, trial.initialCentOffset.rawValue / 1200.0)

        // The second play call (handle-returning) should be the tunable note
        #expect(notePlayer.playCallCount >= 2)
        let tunableFreq = notePlayer.lastFrequency!
        #expect(abs(tunableFreq - expectedTunableFreq) < 0.01)
    }

    // MARK: - commitPitch Tests

    @Test("commitPitch stops handle")
    func commitPitchStopsHandle() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        let handle = try #require(notePlayer.lastHandle)
        session.commitPitch(0.0)
        try await Task.sleep(for: .milliseconds(50))

        #expect(handle.stopCallCount == 1)
    }

    @Test("commitPitch at correcting slider value produces zero cent error")
    func commitPitchAtCenterProducesZeroCentError() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await transitionToPlayingTunable(session)

        let trial = try #require(session.currentTrial)
        // Slider value that cancels initialCentOffset → 0 cent error
        let correctingValue = -trial.initialCentOffset.rawValue / 20.0
        session.commitPitch(correctingValue)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(abs(result.userCentError.rawValue) < 0.01)
    }

    @Test("commitPitch sharp produces positive cent error")
    func commitPitchSharpCentError() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await transitionToPlayingTunable(session)

        let trial = try #require(session.currentTrial)
        // Slider value that produces exactly +10 cents: initialCentOffset + value * 20 = 10
        let value = (10.0 - trial.initialCentOffset.rawValue) / 20.0
        session.commitPitch(value)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError > 0)
        #expect(abs(result.userCentError.rawValue - 10.0) < 0.1)
    }

    @Test("commitPitch notifies observers")
    func commitPitchNotifiesObservers() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        #expect(observer.pitchMatchingCompletedCallCount == 1)
        #expect(observer.lastResult != nil)
    }

    @Test("transitions to showingFeedback after commitPitch")
    func transitionsToShowingFeedback() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        #expect(session.state == .showingFeedback)
    }

    @Test("auto-advances from showingFeedback to awaitingSliderTouch")
    func autoAdvancesFromFeedback() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        // After feedback duration (~400ms), should auto-advance to next trial
        try await waitForState(session, .awaitingSliderTouch, timeout: .seconds(3))
        #expect(session.state == .awaitingSliderTouch)
    }

    // MARK: - Guard Condition Tests

    @Test("start is no-op when not idle")
    func startNoOpWhenNotIdle() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        let playCountBefore = notePlayer.playCallCount
        session.start(settings: defaultPitchMatchingTestSettings)
        try await Task.sleep(for: .milliseconds(50))

        #expect(notePlayer.playCallCount == playCountBefore)
        #expect(session.state == .awaitingSliderTouch)
    }

    @Test("commitPitch is no-op when idle")
    func commitPitchNoOpWhenIdle() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        // Session is idle — commitPitch should do nothing
        session.commitPitch(0.0)

        #expect(session.state == .idle)
        #expect(observer.pitchMatchingCompletedCallCount == 0)
    }

    // MARK: - Cent Error Tests

    @Test("commitPitch flat produces negative cent error")
    func commitPitchFlatCentError() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await transitionToPlayingTunable(session)

        let trial = try #require(session.currentTrial)
        // Slider value that produces exactly -10 cents: initialCentOffset + value * 20 = -10
        let value = (-10.0 - trial.initialCentOffset.rawValue) / 20.0
        session.commitPitch(value)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError < 0)
        #expect(abs(result.userCentError.rawValue + 10.0) < 0.1)
    }

    // MARK: - stop() Tests

    @Test("stop transitions to idle from awaitingSliderTouch")
    func stopTransitionsToIdle() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        session.stop()
        #expect(session.state == .idle)
    }

    // MARK: - Task 1: Enhanced stop() Tests

    @Test("stop from playingReference stops audio and transitions to idle")
    func stopFromPlayingReference() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = .seconds(5)
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .playingReference)

        session.stop()
        #expect(session.state == .idle)
        try await Task.sleep(for: .milliseconds(50))
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("stop from playingTunable stops handle and transitions to idle")
    func stopFromPlayingTunable() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        let handle = try #require(notePlayer.lastHandle)
        session.stop()
        #expect(session.state == .idle)
        try await Task.sleep(for: .milliseconds(50))
        #expect(handle.stopCallCount >= 1)
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("stop from showingFeedback cancels feedback timer and transitions to idle")
    func stopFromShowingFeedback() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        session.stop()
        #expect(session.state == .idle)

        // Verify session does NOT advance to next trial after stop
        try await Task.sleep(for: .milliseconds(600))
        #expect(session.state == .idle)
    }

    @Test("stop from idle is no-op")
    func stopFromIdleIsNoOp() async {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        #expect(session.state == .idle)

        session.stop()
        #expect(session.state == .idle)
        #expect(notePlayer.stopAllCallCount == 0)
    }

    @Test("stop does not notify observers")
    func stopDoesNotNotifyObservers() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        session.stop()
        #expect(observer.pitchMatchingCompletedCallCount == 0)
    }

    @Test("stop clears currentTrial")
    func stopClearsCurrentTrial() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.currentTrial != nil)

        session.stop()
        #expect(session.currentTrial == nil)
    }

    @Test("double stop is safe")
    func doubleStopIsSafe() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        session.stop()
        session.stop()
        #expect(session.state == .idle)
    }

    // MARK: - Pitch Adjustment Tests

    @Test("adjustPitch converts value to frequency and delegates to handle")
    func adjustPitchDelegatesToHandle() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await transitionToPlayingTunable(session)

        let trial = try #require(session.currentTrial)
        let handle = try #require(notePlayer.lastHandle)
        let adjustCountBefore = handle.adjustFrequencyCallCount

        // Slider value that cancels initialCentOffset → exact target frequency
        let correctingValue = -trial.initialCentOffset.rawValue / 20.0
        session.adjustPitch(correctingValue)
        try await Task.sleep(for: .milliseconds(50))

        let expectedFreq = TuningSystem.equalTemperament.frequency(for: trial.targetNote, referencePitch: .concert440)
        #expect(handle.adjustFrequencyCallCount == adjustCountBefore + 1)
        let freq1 = try #require(handle.lastAdjustedFrequency)
        #expect(abs(freq1 - expectedFreq.rawValue) < 0.01)
    }

    @Test("adjustPitch with +1.0 produces frequency (initialCentOffset + 20) cents above reference")
    func adjustPitchPositiveOne() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await transitionToPlayingTunable(session)

        let trial = try #require(session.currentTrial)
        let handle = try #require(notePlayer.lastHandle)
        let adjustCountBefore = handle.adjustFrequencyCallCount
        session.adjustPitch(1.0)
        try await Task.sleep(for: .milliseconds(50))

        let targetFreq = TuningSystem.equalTemperament.frequency(for: trial.targetNote, referencePitch: .concert440).rawValue
        let totalCentOffset = trial.initialCentOffset.rawValue + 20.0
        let expectedFreq = targetFreq * pow(2.0, totalCentOffset / 1200.0)
        #expect(handle.adjustFrequencyCallCount == adjustCountBefore + 1)
        let freq2 = try #require(handle.lastAdjustedFrequency)
        #expect(abs(freq2 - expectedFreq) < 0.01)
    }

    @Test("adjustPitch at correcting value adjusts to target note frequency for intervals")
    func adjustPitchCenterTargetFrequencyForInterval() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72)),
            referencePitch: Frequency(440.0),
            intervals: [.up(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await transitionToPlayingTunable(session)

        let trial = try #require(session.currentTrial)
        let handle = try #require(notePlayer.lastHandle)
        let adjustCountBefore = handle.adjustFrequencyCallCount
        // Slider value that cancels initialCentOffset → exact target frequency
        let correctingValue = -trial.initialCentOffset.rawValue / 20.0
        session.adjustPitch(correctingValue)
        try await Task.sleep(for: .milliseconds(50))

        let expectedTargetFreq = TuningSystem.equalTemperament.frequency(
            for: trial.targetNote, referencePitch: .concert440)
        #expect(handle.adjustFrequencyCallCount == adjustCountBefore + 1)
        let freq3 = try #require(handle.lastAdjustedFrequency)
        #expect(abs(freq3 - expectedTargetFreq.rawValue) < 0.01)
    }

    @Test("commitPitch at correcting value commits result with zero cent error")
    func commitPitchCommitsResult() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await transitionToPlayingTunable(session)

        let trial = try #require(session.currentTrial)
        // Slider value that cancels initialCentOffset → 0 cent error
        let correctingValue = -trial.initialCentOffset.rawValue / 20.0
        session.commitPitch(correctingValue)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(abs(result.userCentError.rawValue) < 0.01)
    }

    @Test("commitPitch produces 10 cent sharp error at correct slider value")
    func commitPitchHalfPositive() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await transitionToPlayingTunable(session)

        let trial = try #require(session.currentTrial)
        // Slider value that produces exactly +10 cents: initialCentOffset + value * 20 = 10
        let value = (10.0 - trial.initialCentOffset.rawValue) / 20.0
        session.commitPitch(value)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError > 0)
        #expect(abs(result.userCentError.rawValue - 10.0) < 0.1)
    }

    @Test("adjustPitch is no-op when idle")
    func adjustPitchNoOpWhenIdle() async {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        // Session is idle
        session.adjustPitch(0.5)
        try? await Task.sleep(for: .milliseconds(50))

        let adjustCount = notePlayer.handleHistory.reduce(0) { $0 + $1.adjustFrequencyCallCount }
        #expect(adjustCount == 0)
    }

    // MARK: - Interval State Tests (Task 1)

    @Test("currentInterval is nil initially")
    func currentIntervalNilInitially() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.currentInterval == nil)
    }

    @Test("isIntervalMode is false initially")
    func isIntervalModeFalseInitially() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.isIntervalMode == false)
    }

    @Test("currentInterval is prime with unison intervals")
    func currentIntervalPrimeWithUnison() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        #expect(session.currentInterval == .prime)
        #expect(session.isIntervalMode == false)
    }

    @Test("currentInterval is perfectFifth with interval set")
    func currentIntervalPerfectFifth() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            referencePitch: Frequency(440.0),
            intervals: [.up(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await waitForState(session, .awaitingSliderTouch)

        #expect(session.currentInterval == .up(.perfectFifth))
        #expect(session.isIntervalMode == true)
    }

    @Test("stop clears interval state")
    func stopClearsIntervalState() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            referencePitch: Frequency(440.0),
            intervals: [.up(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.currentInterval != nil)

        session.stop()
        #expect(session.currentInterval == nil)
        #expect(session.isIntervalMode == false)
    }

    // MARK: - Interval Trial Generation Tests (Task 3)

    @Test("generateTrial with prime produces targetNote equal to referenceNote")
    func generateTrialPrimeTargetEqualsReference() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        let settings = PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72)),
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        try await waitForState(session, .awaitingSliderTouch)

        let trial = try #require(session.currentTrial)
        #expect(trial.targetNote == trial.referenceNote)
    }

    @Test("generateTrial with perfectFifth produces target 7 semitones above reference")
    func generateTrialPerfectFifthTarget() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72)),
            referencePitch: Frequency(440.0),
            intervals: [.up(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await waitForState(session, .awaitingSliderTouch)

        let trial = try #require(session.currentTrial)
        #expect(trial.targetNote.rawValue == trial.referenceNote.rawValue + 7)
    }

    @Test("generateTrial constrains reference note range for interval")
    func generateTrialConstrainsRangeForInterval() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(125)),
            referencePitch: Frequency(440.0),
            intervals: [.up(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await waitForState(session, .awaitingSliderTouch)

        let trial = try #require(session.currentTrial)
        // Reference note must be <= 120 (127 - 7) to allow perfect fifth transposition
        #expect(trial.referenceNote.rawValue <= 120)
        #expect(trial.targetNote.rawValue <= 127)
    }

    @Test("generateTrial with downward perfectFifth produces target 7 semitones below reference")
    func generateTrialDownwardPerfectFifthTarget() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72)),
            referencePitch: Frequency(440.0),
            intervals: [.down(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await waitForState(session, .awaitingSliderTouch)

        let trial = try #require(session.currentTrial)
        #expect(trial.targetNote.rawValue == trial.referenceNote.rawValue - 7)
    }

    @Test("generateTrial constrains reference note minimum for downward interval")
    func generateTrialConstrainsRangeForDownwardInterval() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(0), upperBound: MIDINote(84)),
            referencePitch: Frequency(440.0),
            intervals: [.down(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await waitForState(session, .awaitingSliderTouch)

        let trial = try #require(session.currentTrial)
        // Reference note must be >= 7 so target (ref - 7) stays >= 0
        #expect(trial.referenceNote.rawValue >= 7)
        #expect(trial.targetNote.rawValue >= 0)
    }

    // MARK: - Tuning System and Anchor Tests (Task 4)

    @Test("referenceFrequency anchor is target note frequency for intervals")
    func referenceFrequencyAnchorIsTargetFrequency() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72)),
            referencePitch: Frequency(440.0),
            intervals: [.up(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await waitForState(session, .awaitingSliderTouch)

        let trial = try #require(session.currentTrial)
        #expect(trial.targetNote.rawValue == trial.referenceNote.rawValue + 7)
        // referenceFrequency should be the target note frequency, not the reference note frequency
        let expectedTargetFreq = TuningSystem.equalTemperament.frequency(
            for: trial.targetNote, referencePitch: .concert440)
        let refFreq = try #require(session.referenceFrequency)
        #expect(abs(refFreq.rawValue - expectedTargetFreq.rawValue) < 0.01)
    }

    @Test("tunable note is detuned from target note for intervals")
    func tunableNoteDetunedFromTargetForInterval() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72)),
            referencePitch: Frequency(440.0),
            intervals: [.up(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await transitionToPlayingTunable(session)

        let trial = try #require(session.currentTrial)
        #expect(trial.targetNote.rawValue == trial.referenceNote.rawValue + 7)

        // Tunable note should be detuned from TARGET (67), not reference (60)
        let expectedFreq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: trial.targetNote, offset: trial.initialCentOffset),
            referencePitch: .concert440)

        #expect(notePlayer.playCallCount >= 2)
        let tunableFreq = notePlayer.lastFrequency!
        #expect(abs(tunableFreq - expectedFreq.rawValue) < 0.01)
    }

    @Test("commitPitch at correcting value produces zero cent error for interval")
    func commitPitchAtCenterZeroCentErrorForInterval() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72)),
            referencePitch: Frequency(440.0),
            intervals: [.up(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await transitionToPlayingTunable(session)

        let trial = try #require(session.currentTrial)
        // Slider value that cancels initialCentOffset → 0 cent error
        let correctingValue = -trial.initialCentOffset.rawValue / 20.0
        session.commitPitch(correctingValue)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(abs(result.userCentError.rawValue) < 0.01)
    }

    @Test("CompletedPitchMatchingTrial carries session tuningSystem")
    func completedPitchMatchingCarriesTuningSystem() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.tuningSystem == .equalTemperament)
    }

    @Test("start uses intervals parameter for session")
    func startUsesIntervalsParameter() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            referencePitch: Frequency(440.0),
            intervals: [.up(.majorThird), .up(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await waitForState(session, .awaitingSliderTouch)

        let interval = try #require(session.currentInterval)
        #expect(interval == .up(.majorThird) || interval == .up(.perfectFifth))
    }

    @Test("start with perfectFifth sets currentInterval to perfectFifth")
    func startWithPerfectFifthSetsCurrentInterval() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            referencePitch: Frequency(440.0),
            intervals: [.up(.perfectFifth)],
            noteDuration: NoteDuration(0.3)
        ))
        try await waitForState(session, .awaitingSliderTouch)

        #expect(session.currentInterval == .up(.perfectFifth))
        #expect(session.isIntervalMode)
        session.stop()
    }

    @Test("start with multiple intervals picks from the provided set")
    func startWithMultipleIntervals() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        let intervals: Set<DirectedInterval> = [.prime, .up(.perfectFifth)]
        session.start(settings: PitchMatchingSettings(
            referencePitch: Frequency(440.0),
            intervals: intervals,
            noteDuration: NoteDuration(0.3)
        ))
        try await waitForState(session, .awaitingSliderTouch)

        let interval = try #require(session.currentInterval)
        #expect(intervals.contains(interval))
        session.stop()
    }

    // MARK: - Full Cycle Tests

    @Test("full cycle: idle → playingReference → awaitingSliderTouch → playingTunable → showingFeedback → loop")
    func fullStateCycle() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()

        #expect(session.state == .idle)

        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.state == .awaitingSliderTouch)

        session.adjustPitch(0.0)
        #expect(session.state == .playingTunable)
        try await Task.sleep(for: .milliseconds(50))

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)
        #expect(observer.pitchMatchingCompletedCallCount == 1)

        // Wait for auto-advance to next trial
        try await waitForState(session, .awaitingSliderTouch, timeout: .seconds(3))

        session.adjustPitch(0.0)
        try await Task.sleep(for: .milliseconds(50))

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)
        #expect(observer.pitchMatchingCompletedCallCount == 2)
    }

    // MARK: - Tuning System Visibility Tests (Story 30.3)

    @Test("sessionTuningSystem is equalTemperament by default")
    func sessionTuningSystemDefault() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.sessionTuningSystem == .equalTemperament)
    }

    @Test("sessionTuningSystem reflects settings after start")
    func sessionTuningSystemFromSettings() async {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = true
        let settings = PitchMatchingSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            tuningSystem: .justIntonation,
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        await Task.yield()
        #expect(session.sessionTuningSystem == .justIntonation)
        session.stop()
    }

    @Test("sessionTuningSystem resets to equalTemperament after stop")
    func sessionTuningSystemResetsOnStop() async {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = true
        let settings = PitchMatchingSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            tuningSystem: .justIntonation,
            noteDuration: NoteDuration(0.3)
        )
        session.start(settings: settings)
        await Task.yield()
        session.stop()
        #expect(session.sessionTuningSystem == .equalTemperament)
    }

    // MARK: - Continuation Safety Tests (Story 64.1)

    @Test("adjustPitch then commitPitch in rapid sequence does not crash")
    func adjustThenCommitRapidSequence() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = true
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        // Both call resumeSliderContinuationIfNeeded — only the first should succeed
        session.adjustPitch(0.5)
        session.commitPitch(0.5)

        // Session should not be idle (still running) and should not have crashed
        #expect(session.state != .idle)
        session.stop()
    }

    @Test("commitPitch when already in playingTunable is a no-op for continuation")
    func commitPitchWhenAlreadyPlayingTunable() async throws {
        let (session, notePlayer, _, observer) = makePitchMatchingSession()
        notePlayer.instantPlayback = true
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        #expect(session.state == .playingTunable)

        // commitPitch should commit the result, not crash from double-resume
        session.commitPitch(0.0)

        try await waitForState(session, .showingFeedback)
        #expect(observer.pitchMatchingCompletedCallCount == 1)
        session.stop()
    }

    @Test("stop during showingFeedback prevents playNextTrial from running")
    func stopDuringFeedbackPreventsNextTrial() async throws {
        let (session, notePlayer, _, observer) = makePitchMatchingSession()
        notePlayer.instantPlayback = true
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        // Stop during feedback phase
        session.stop()
        #expect(session.state == .idle)

        // Wait long enough for the feedback timer to have fired if the guard were missing
        try await Task.sleep(for: .milliseconds(600))

        // Session must remain idle — playNextTrial should not have run
        #expect(session.state == .idle)
        #expect(observer.pitchMatchingCompletedCallCount == 1)
    }

    // MARK: - Actor Isolation Tests

    @Test("observable state from training loop is readable on MainActor without await")
    func stateUpdatesOnMainActor() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        // Synchronous reads prove shared MainActor isolation between
        // the test (MainActor) and the session's internal Task that
        // mutated these properties. If the session were on a different
        // actor, the compiler would require `await` for these reads.
        MainActor.assertIsolated()
        #expect(session.state == .awaitingSliderTouch)
        #expect(session.currentTrial != nil)
        #expect(session.referenceFrequency != nil)

        session.stop()
    }
}

// MARK: - Audio Interruption and Lifecycle Tests

@Suite("PitchMatchingSession Audio Interruption Tests", .serialized)
struct PitchMatchingSessionAudioInterruptionTests {

    private static let testBackgroundNotification = Notification.Name("test.background")

    // MARK: - Audio Interruption Tests

    @Test("Audio interruption stops from playingTunable")
    func audioInterruptionStopsFromPlayingTunable() async throws {
        let mock = MockAudioInterruptionObserver()
        let (session, _, _, _) = makePitchMatchingSession(audioInterruptionObserver: mock)
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        mock.simulateInterruption()

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption stops from awaitingSliderTouch")
    func audioInterruptionStopsFromAwaitingSliderTouch() async throws {
        let mock = MockAudioInterruptionObserver()
        let (session, _, _, _) = makePitchMatchingSession(audioInterruptionObserver: mock)
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        mock.simulateInterruption()

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption on idle is safe")
    func audioInterruptionOnIdleIsSafe() async throws {
        let mock = MockAudioInterruptionObserver()
        let (session, _, _, _) = makePitchMatchingSession(audioInterruptionObserver: mock)
        #expect(session.state == .idle)

        mock.simulateInterruption()

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .idle)
    }

    @Test("Audio interruption stops from playingReference")
    func audioInterruptionStopsFromPlayingReference() async throws {
        let mock = MockAudioInterruptionObserver()
        let (session, notePlayer, _, _) = makePitchMatchingSession(audioInterruptionObserver: mock)
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = .seconds(5)
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .playingReference)

        mock.simulateInterruption()

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption stops from showingFeedback")
    func audioInterruptionStopsFromShowingFeedback() async throws {
        let mock = MockAudioInterruptionObserver()
        let (session, _, _, _) = makePitchMatchingSession(audioInterruptionObserver: mock)
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        mock.simulateInterruption()

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    // MARK: - Background Notification Tests

    @Test("Background notification stops from playingTunable")
    func backgroundNotificationStopsFromPlayingTunable() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _) = makePitchMatchingSession(
            notificationCenter: nc,
            backgroundNotificationName: Self.testBackgroundNotification
        )
        session.start(settings: defaultPitchMatchingTestSettings)
        try await transitionToPlayingTunable(session)

        nc.post(name: Self.testBackgroundNotification, object: nil)

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Background notification stops from awaitingSliderTouch")
    func backgroundNotificationStopsFromAwaitingSliderTouch() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _) = makePitchMatchingSession(
            notificationCenter: nc,
            backgroundNotificationName: Self.testBackgroundNotification
        )
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        nc.post(name: Self.testBackgroundNotification, object: nil)

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Background notification on idle is safe")
    func backgroundNotificationOnIdleIsSafe() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _) = makePitchMatchingSession(
            notificationCenter: nc,
            backgroundNotificationName: Self.testBackgroundNotification
        )
        #expect(session.state == .idle)

        nc.post(name: Self.testBackgroundNotification, object: nil)

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .idle)
    }

    // MARK: - Restart Tests

    @Test("Training can restart after interruption stop")
    func canRestartAfterInterruptionStop() async throws {
        let mock = MockAudioInterruptionObserver()
        let (session, _, _, _) = makePitchMatchingSession(audioInterruptionObserver: mock)
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        mock.simulateInterruption()
        try await waitForState(session, .idle)

        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.state == .awaitingSliderTouch)
    }

    @Test("Training can restart after background stop")
    func canRestartAfterBackgroundStop() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _) = makePitchMatchingSession(
            notificationCenter: nc,
            backgroundNotificationName: Self.testBackgroundNotification
        )
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        nc.post(name: Self.testBackgroundNotification, object: nil)
        try await waitForState(session, .idle)

        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.state == .awaitingSliderTouch)
    }
}

// MARK: - MIDI Pitch Bend Tests

func makePitchMatchingSessionWithMIDI(
) -> (session: PitchMatchingSession, notePlayer: MockNotePlayer, profile: MockTrainingProfile, observer: MockPitchMatchingObserver, midiInput: MockMIDIInput) {
    let notePlayer = MockNotePlayer()
    let profile = MockTrainingProfile()
    let observer = MockPitchMatchingObserver()
    let midiInput = MockMIDIInput()
    let session = PitchMatchingSession(
        notePlayer: notePlayer,
        profile: profile,
        observers: [observer],
        midiInput: midiInput,
        audioInterruptionObserver: NoOpAudioInterruptionObserver()
    )
    return (session, notePlayer, profile, observer, midiInput)
}

@Suite("PitchMatchingSession MIDI Pitch Bend")
struct PitchMatchingSessionMIDIPitchBendTests {

    @Test("Pitch bend in awaitingSliderTouch triggers transition to playingTunable")
    func pitchBendTriggersAutoStart() async throws {
        let (session, _, _, _, midiInput) = makePitchMatchingSessionWithMIDI()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        midiInput.send(.pitchBend(value: PitchBendValue(10000), channel: 0, timestamp: 0))
        try await waitForState(session, .playingTunable)
    }

    @Test("Continuous pitch bend events call adjustFrequency with mapped values")
    func continuousPitchBendAdjustsFrequency() async throws {
        let (session, notePlayer, _, _, midiInput) = makePitchMatchingSessionWithMIDI()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        // First pitch bend triggers auto-start
        midiInput.send(.pitchBend(value: PitchBendValue(12000), channel: 0, timestamp: 0))
        try await waitForState(session, .playingTunable)

        // Wait for tunable note to start (second play call sets handle)
        try await waitForCondition { notePlayer.playCallCount >= 2 }

        let handle = try #require(notePlayer.lastHandle)
        let adjustCountBefore = handle.adjustFrequencyCallCount

        // Second pitch bend adjusts frequency
        midiInput.send(.pitchBend(value: PitchBendValue(14000), channel: 0, timestamp: 0))
        try await waitForCondition { handle.adjustFrequencyCallCount > adjustCountBefore }
    }

    @Test("Pitch bend return to neutral after deflection triggers commitPitch")
    func neutralReturnAfterDeflectionCommits() async throws {
        let (session, notePlayer, _, observer, midiInput) = makePitchMatchingSessionWithMIDI()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        // First bend: auto-start + deflect away from center
        midiInput.send(.pitchBend(value: PitchBendValue(12000), channel: 0, timestamp: 0))
        try await waitForState(session, .playingTunable)
        try await waitForCondition { notePlayer.playCallCount >= 2 }

        // Return to center → should commit
        midiInput.send(.pitchBend(value: PitchBendValue(8192), channel: 0, timestamp: 0))
        try await waitForState(session, .showingFeedback)

        #expect(observer.resultHistory.count == 1)
    }

    @Test("Pitch bend in neutral zone without prior deflection does not commit")
    func neutralWithoutDeflectionDoesNotCommit() async throws {
        let (session, _, _, observer, midiInput) = makePitchMatchingSessionWithMIDI()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        // Send center value first — triggers auto-start but should NOT commit
        midiInput.send(.pitchBend(value: PitchBendValue(8192), channel: 0, timestamp: 0))
        try await waitForState(session, .playingTunable)

        // Should be playingTunable, not showingFeedback
        #expect(session.state == .playingTunable)
        #expect(observer.resultHistory.isEmpty)
    }

    @Test("hasBeenDeflected resets on new trial")
    func hasBeenDeflectedResetsOnNewTrial() async throws {
        let (session, notePlayer, _, observer, midiInput) = makePitchMatchingSessionWithMIDI()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        // Deflect and commit first trial
        midiInput.send(.pitchBend(value: PitchBendValue(12000), channel: 0, timestamp: 0))
        try await waitForState(session, .playingTunable)
        try await waitForCondition { notePlayer.playCallCount >= 2 }
        midiInput.send(.pitchBend(value: PitchBendValue(8192), channel: 0, timestamp: 0))
        try await waitForState(session, .showingFeedback)
        #expect(observer.resultHistory.count == 1)

        // Wait for next trial
        try await waitForState(session, .awaitingSliderTouch)

        // Send neutral value — should auto-start but NOT commit (hasBeenDeflected was reset)
        midiInput.send(.pitchBend(value: PitchBendValue(8192), channel: 0, timestamp: 0))
        try await waitForState(session, .playingTunable)

        #expect(session.state == .playingTunable)
        #expect(observer.resultHistory.count == 1)
    }

    @Test("noteOn and noteOff events are ignored during pitch matching")
    func noteEventsIgnored() async throws {
        let (session, _, _, observer, midiInput) = makePitchMatchingSessionWithMIDI()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 0))
        midiInput.send(.noteOff(note: MIDINote(60), velocity: MIDIVelocity(1), timestamp: 0))
        try await Task.sleep(for: .milliseconds(100))

        // Should still be awaiting slider touch — note events don't trigger anything
        #expect(session.state == .awaitingSliderTouch)
        #expect(observer.resultHistory.isEmpty)
    }

    @Test("Session with nil midiInput works identically to before")
    func nilMidiInputBackwardCompatible() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        session.adjustPitch(0.5)
        try await waitForState(session, .playingTunable)

        session.commitPitch(0.5)
        try await waitForState(session, .showingFeedback)
    }

    @Test("MIDI listening task is cancelled when stop() is called")
    func midiListeningCancelledOnStop() async throws {
        let (session, _, _, _, midiInput) = makePitchMatchingSessionWithMIDI()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        session.stop()
        #expect(session.state == .idle)

        // Sending pitch bend after stop should not change state
        midiInput.send(.pitchBend(value: PitchBendValue(12000), channel: 0, timestamp: 0))
        try await Task.sleep(for: .milliseconds(100))

        #expect(session.state == .idle)
    }

    @Test("midiPitchBendValue is set on pitch bend events and cleared on stop")
    func midiPitchBendValueLifecycle() async throws {
        let (session, _, _, _, midiInput) = makePitchMatchingSessionWithMIDI()
        #expect(session.midiPitchBendValue == nil)

        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        midiInput.send(.pitchBend(value: PitchBendValue(12000), channel: 0, timestamp: 0))
        try await waitForCondition { session.midiPitchBendValue != nil }

        session.stop()
        #expect(session.midiPitchBendValue == nil)
    }
}
