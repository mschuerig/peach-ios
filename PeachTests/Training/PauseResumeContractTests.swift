import Foundation
import Testing
@testable import Peach

// MARK: - PitchMatchingSession

@Suite("PitchMatchingSession pause/resume contract")
struct PitchMatchingSessionPauseResumeTests {

    @Test("pause from awaitingSliderTouch preserves currentTrial and keeps state non-idle")
    func pausePreservesCurrentTrialAndKeepsNonIdle() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        let trialBefore = try #require(session.currentTrial)

        session.pause()

        #expect(session.currentTrial?.referenceNote == trialBefore.referenceNote)
        #expect(session.currentTrial?.targetNote == trialBefore.targetNote)
        #expect(session.currentTrial?.initialCentOffset == trialBefore.initialCentOffset)
        #expect(session.isIdle == false, "paused session must not appear idle to the coordinator")
        session.stop()
    }

    @Test("resume from paused re-plays the reference for the same trial")
    func resumeReplaysReferenceForPreservedTrial() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        let trialBefore = try #require(session.currentTrial)
        let playCallsBefore = notePlayer.playCallCount

        session.pause()
        session.resume()

        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.currentTrial?.referenceNote == trialBefore.referenceNote)
        #expect(notePlayer.playCallCount > playCallsBefore, "resume must re-issue audio playback")
        session.stop()
    }

    @Test("resume recomputes the justIntonation in-tune target from the preserved trial's interval")
    func resumeRecomputesJustIntonationInTuneTarget() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: PitchMatchingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72)),
            referencePitch: Frequency(440.0),
            intervals: [.up(.majorThird)],
            tuningSystem: .justIntonation,
            noteDuration: NoteDuration(0.3)
        ))
        try await waitForState(session, .awaitingSliderTouch)
        let trialBefore = try #require(session.currentTrial)

        session.pause()
        session.resume()
        try await waitForState(session, .awaitingSliderTouch)

        let preserved = try #require(session.currentTrial)
        #expect(preserved.referenceNote == trialBefore.referenceNote)
        // In-tune target is recomputed from the preserved trial's stored interval —
        // the pure major third above the equal-tempered reference, no drift.
        let referenceFreq = TuningSystem.equalTemperament.frequency(
            for: preserved.referenceNote, referencePitch: .concert440)
        let pureThird = Frequency(referenceFreq.rawValue * pow(2.0, 386.314 / 1200.0))
        let inTune = try #require(session.inTuneTargetFrequency)
        #expect(abs(centsAbove(pureThird, inTune)) < 0.001)
        session.stop()
    }

    @Test("pause when idle is a no-op")
    func pauseWhenIdleIsNoOp() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.isIdle)

        session.pause()

        #expect(session.isIdle)
        #expect(session.currentTrial == nil)
    }

    @Test("resume when not paused is a no-op")
    func resumeWhenNotPausedIsNoOp() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        let stateBefore = session.state
        let trialBefore = session.currentTrial

        session.resume()

        #expect(session.state == stateBefore)
        #expect(session.currentTrial?.referenceNote == trialBefore?.referenceNote)
        session.stop()
    }

    @Test("stop after pause clears trial and goes idle")
    func stopAfterPauseClearsState() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        session.pause()
        #expect(session.currentTrial != nil)

        session.stop()

        try await waitForState(session, .idle)
        #expect(session.currentTrial == nil)
        #expect(session.lastResult == nil)
        #expect(session.sessionBestCentError == nil)
    }

    @Test("pause from playingTunable clears hasBeenDeflected so resumed trial cannot auto-commit on first neutral bend")
    func pauseClearsMidiDeflectionState() async throws {
        let (session, _, _, _, midiInput) = makePitchMatchingSessionWithMIDI()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)

        // Drive the session into `.playingTunable` with a deflected pitch bend so
        // `hasBeenDeflected = true`. Without the pause-time clear, resume's first
        // entry into playingTunable would carry this stale flag and the next neutral
        // bend would commit the centered pitch — silent auto-fail of the resumed trial.
        midiInput.send(.pitchBend(value: PitchBendValue(12000), channel: 0, timestamp: 0))
        try await waitForState(session, .playingTunable)

        session.pause()
        session.resume()
        try await waitForState(session, .awaitingSliderTouch)

        // First neutral bend transitions awaitingSliderTouch → playingTunable. Expected.
        midiInput.send(.pitchBend(value: PitchBendValue.center, channel: 0, timestamp: 0))
        try await waitForState(session, .playingTunable)

        // Second neutral bend: with the bug, hasBeenDeflected==true → commit. With
        // the fix, hasBeenDeflected was cleared on pause → just adjusts pitch.
        midiInput.send(.pitchBend(value: PitchBendValue.center, channel: 0, timestamp: 0))
        try await Task.sleep(for: .milliseconds(50))

        #expect(session.state == .playingTunable, "neutral bend after resume must not auto-commit a stale deflection")
        #expect(session.lastResult == nil, "no trial result should have been recorded")
        session.stop()
    }

    // MARK: - Settings-aware reconcile

    @Test("reconcile(with:) when idle is a no-op")
    func reconcileWhenIdleIsNoOp() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.isIdle)
        session.reconcile(with: defaultPitchMatchingTestSettings)
        #expect(session.isIdle)
    }

    @Test("reconcile(with:) unchanged on an active session does not restart")
    func reconcileActiveUnchangedDoesNotRestart() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        let playCallsBefore = notePlayer.playCallCount

        session.reconcile(with: defaultPitchMatchingTestSettings)

        #expect(session.state == .awaitingSliderTouch)
        #expect(notePlayer.playCallCount == playCallsBefore, "unchanged active reconcile must not restart")
        session.stop()
    }

    @Test("reconcile(with:) changed on an active session restarts with the new settings")
    func reconcileActiveChangedRestarts() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        let playCallsBefore = notePlayer.playCallCount

        var changed = defaultPitchMatchingTestSettings
        changed.noteDuration = NoteDuration(0.5)
        session.reconcile(with: changed)

        try await waitForState(session, .awaitingSliderTouch)
        #expect(notePlayer.playCallCount > playCallsBefore, "changed reconcile must restart and replay")
        session.stop()
    }

    @Test("reconcile(with:) unchanged on a paused session resumes the preserved trial")
    func reconcilePausedUnchangedResumes() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.start(settings: defaultPitchMatchingTestSettings)
        try await waitForState(session, .awaitingSliderTouch)
        let referenceBefore = session.currentTrial?.referenceNote
        let playCallsBefore = notePlayer.playCallCount
        session.pause()

        session.reconcile(with: defaultPitchMatchingTestSettings)

        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.currentTrial?.referenceNote == referenceBefore, "unchanged reconcile preserves the trial")
        #expect(notePlayer.playCallCount > playCallsBefore, "resume re-plays the reference")
        session.stop()
    }

    @Test("PitchMatchingSettings Equatable distinguishes a changed field")
    func settingsEquatableDistinguishesChange() {
        var changed = defaultPitchMatchingTestSettings
        changed.noteDuration = NoteDuration(0.5)
        #expect(defaultPitchMatchingTestSettings != changed)
        #expect(defaultPitchMatchingTestSettings == defaultPitchMatchingTestSettings)
    }
}

// MARK: - PitchDiscriminationSession

@Suite("PitchDiscriminationSession pause/resume contract")
struct PitchDiscriminationSessionPauseResumeTests {

    @Test("pause from awaitingAnswer preserves trial state and keeps non-idle")
    func pausePreservesTrialState() async throws {
        let fixture = makePitchDiscriminationSession()
        fixture.session.start(settings: defaultTestSettings)
        try await waitForState(fixture.session, .awaitingAnswer)
        let intervalBefore = fixture.session.currentInterval

        fixture.session.pause()

        #expect(fixture.session.currentInterval == intervalBefore)
        #expect(fixture.session.isIdle == false, "paused session must not appear idle to the coordinator")
        fixture.session.stop()
    }

    @Test("resume from paused re-plays the reference for the preserved trial")
    func resumeReplaysReference() async throws {
        let fixture = makePitchDiscriminationSession()
        fixture.session.start(settings: defaultTestSettings)
        try await waitForState(fixture.session, .awaitingAnswer)
        let intervalBefore = fixture.session.currentInterval
        let playCallsBefore = fixture.mockPlayer.playCallCount

        fixture.session.pause()
        fixture.session.resume()

        try await waitForState(fixture.session, .awaitingAnswer)
        #expect(fixture.session.currentInterval == intervalBefore)
        #expect(fixture.mockPlayer.playCallCount > playCallsBefore, "resume must re-issue audio playback")
        fixture.session.stop()
    }

    @Test("pause when idle is a no-op")
    func pauseWhenIdleIsNoOp() async {
        let fixture = makePitchDiscriminationSession()
        #expect(fixture.session.isIdle)

        fixture.session.pause()

        #expect(fixture.session.isIdle)
    }

    @Test("resume when not paused is a no-op")
    func resumeWhenNotPausedIsNoOp() async throws {
        let fixture = makePitchDiscriminationSession()
        fixture.session.start(settings: defaultTestSettings)
        try await waitForState(fixture.session, .awaitingAnswer)
        let stateBefore = fixture.session.state

        fixture.session.resume()

        #expect(fixture.session.state == stateBefore)
        fixture.session.stop()
    }

    @Test("stop after pause clears trial state and goes idle")
    func stopAfterPauseClearsState() async throws {
        let fixture = makePitchDiscriminationSession()
        fixture.session.start(settings: defaultTestSettings)
        try await waitForState(fixture.session, .awaitingAnswer)
        fixture.session.pause()

        fixture.session.stop()

        try await waitForState(fixture.session, .idle)
        #expect(fixture.session.currentInterval == nil)
        #expect(fixture.session.sessionBestCentDifference == nil)
    }

    @Test("pause from showingFeedback clears feedback overlay so it does not leak into resumed trial")
    func pauseClearsShowingFeedbackOverlay() async throws {
        let fixture = makePitchDiscriminationSession()
        fixture.session.start(settings: defaultTestSettings)
        try await waitForState(fixture.session, .awaitingAnswer)
        fixture.session.handleAnswer(isHigher: true)
        try await waitForState(fixture.session, .showingFeedback)
        #expect(fixture.session.showFeedback == true)

        fixture.session.pause()

        #expect(fixture.session.showFeedback == false, "feedback overlay must clear on pause")
        #expect(fixture.session.isLastAnswerCorrect == nil)
        fixture.session.stop()
    }

    // MARK: - Settings-aware reconcile

    @Test("reconcile(with:) when idle is a no-op")
    func reconcileWhenIdleIsNoOp() async {
        let fixture = makePitchDiscriminationSession()
        #expect(fixture.session.isIdle)
        fixture.session.reconcile(with: defaultTestSettings)
        #expect(fixture.session.isIdle)
    }

    @Test("reconcile(with:) unchanged on an active session does not restart")
    func reconcileActiveUnchangedDoesNotRestart() async throws {
        let fixture = makePitchDiscriminationSession()
        fixture.session.start(settings: defaultTestSettings)
        try await waitForState(fixture.session, .awaitingAnswer)
        let playCallsBefore = fixture.mockPlayer.playCallCount

        fixture.session.reconcile(with: defaultTestSettings)

        #expect(fixture.session.state == .awaitingAnswer)
        #expect(fixture.mockPlayer.playCallCount == playCallsBefore, "unchanged active reconcile must not restart")
        fixture.session.stop()
    }

    @Test("reconcile(with:) changed on an active session restarts with the new settings")
    func reconcileActiveChangedRestarts() async throws {
        let fixture = makePitchDiscriminationSession()
        fixture.session.start(settings: defaultTestSettings)
        try await waitForState(fixture.session, .awaitingAnswer)
        let playCallsBefore = fixture.mockPlayer.playCallCount

        var changed = defaultTestSettings
        changed.noteDuration = NoteDuration(0.5)
        fixture.session.reconcile(with: changed)

        try await waitForState(fixture.session, .awaitingAnswer)
        #expect(fixture.mockPlayer.playCallCount > playCallsBefore, "changed reconcile must restart and replay")
        fixture.session.stop()
    }

    @Test("reconcile(with:) unchanged on a paused session resumes the preserved trial")
    func reconcilePausedUnchangedResumes() async throws {
        let fixture = makePitchDiscriminationSession()
        fixture.session.start(settings: defaultTestSettings)
        try await waitForState(fixture.session, .awaitingAnswer)
        let intervalBefore = fixture.session.currentInterval
        let playCallsBefore = fixture.mockPlayer.playCallCount
        fixture.session.pause()

        fixture.session.reconcile(with: defaultTestSettings)

        try await waitForState(fixture.session, .awaitingAnswer)
        #expect(fixture.session.currentInterval == intervalBefore, "unchanged reconcile preserves the trial")
        #expect(fixture.mockPlayer.playCallCount > playCallsBefore, "resume re-plays the reference")
        fixture.session.stop()
    }

    @Test("PitchDiscriminationSettings Equatable distinguishes a changed field")
    func settingsEquatableDistinguishesChange() {
        var changed = defaultTestSettings
        changed.noteDuration = NoteDuration(0.5)
        #expect(defaultTestSettings != changed)
        #expect(defaultTestSettings == defaultTestSettings)
    }
}

// MARK: - ContinuousRhythmMatchingSession (research-build only)

#if PEACH_RESEARCH
@Suite("ContinuousRhythmMatchingSession pause/resume contract")
struct ContinuousRhythmMatchingSessionPauseResumeTests {

    private func makeSession() -> ContinuousRhythmMatchingSession {
        ContinuousRhythmMatchingSession(
            beatSequencer: MockBeatSequencer()
        )
    }

    private var settings: ContinuousRhythmMatchingSettings {
        ContinuousRhythmMatchingSettings(
            tempo: TempoBPM(120),
            enabledGapPositions: [.second]
        )
    }

    @Test("pause keeps state non-idle until stop")
    func pauseKeepsNonIdle() {
        let session = makeSession()
        session.start(settings: settings)
        #expect(session.isIdle == false)

        session.pause()

        #expect(session.isIdle == false, "paused session must not appear idle to the coordinator")
        session.stop()
    }

    @Test("resume restarts the trial cycle without clearing settings")
    func resumeRestartsTrialCycle() {
        let session = makeSession()
        session.start(settings: settings)
        session.pause()

        session.resume()

        #expect(session.isIdle == false)
        #expect(session.cyclesInCurrentTrial == 0)
        session.stop()
    }

    @Test("pause when idle is a no-op")
    func pauseWhenIdleIsNoOp() {
        let session = makeSession()
        #expect(session.isIdle)

        session.pause()

        #expect(session.isIdle)
    }

    // MARK: - Settings-aware reconcile

    private var changedSettings: ContinuousRhythmMatchingSettings {
        ContinuousRhythmMatchingSettings(tempo: TempoBPM(100), enabledGapPositions: [.second])
    }

    @Test("reconcile(with:) when idle is a no-op")
    func reconcileWhenIdleIsNoOp() {
        let session = makeSession()
        #expect(session.isIdle)

        session.reconcile(with: settings)

        #expect(session.isIdle)
    }

    @Test("reconcile(with:) unchanged on an active session keeps it running")
    func reconcileActiveUnchangedKeepsRunning() {
        let session = makeSession()
        session.start(settings: settings)
        #expect(session.isIdle == false)

        session.reconcile(with: settings)

        #expect(session.isIdle == false)
        session.stop()
    }

    @Test("reconcile(with:) changed on an active session restarts the trial cycle")
    func reconcileChangedRestarts() {
        let session = makeSession()
        session.start(settings: settings)
        #expect(session.isIdle == false)

        session.reconcile(with: changedSettings)

        #expect(session.isIdle == false)
        #expect(session.cyclesInCurrentTrial == 0)
        session.stop()
    }

    @Test("ContinuousRhythmMatchingSettings Equatable distinguishes a changed field")
    func settingsEquatableDistinguishesChange() {
        #expect(settings != changedSettings)
        #expect(settings == ContinuousRhythmMatchingSettings(tempo: TempoBPM(120), enabledGapPositions: [.second]))
    }
}
#endif
