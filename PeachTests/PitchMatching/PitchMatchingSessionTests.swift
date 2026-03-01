import Foundation
import Testing
import AVFoundation
import UIKit
@testable import Peach

// MARK: - Test Helpers

func waitForState(
    _ session: PitchMatchingSession,
    _ expectedState: PitchMatchingSessionState,
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

// MARK: - Factory

func makePitchMatchingSession(
    userSettings: MockUserSettings = {
        let s = MockUserSettings()
        s.noteDuration = NoteDuration(0.3)
        return s
    }(),
    notificationCenter: NotificationCenter = .default,
    backgroundNotificationName: Notification.Name? = UIApplication.didEnterBackgroundNotification,
    foregroundNotificationName: Notification.Name? = UIApplication.willEnterForegroundNotification
) -> (session: PitchMatchingSession, notePlayer: MockNotePlayer, profile: MockPitchMatchingProfile, observer: MockPitchMatchingObserver, mockSettings: MockUserSettings) {
    let notePlayer = MockNotePlayer()
    let profile = MockPitchMatchingProfile()
    let observer = MockPitchMatchingObserver()
    let session = PitchMatchingSession(
        notePlayer: notePlayer,
        profile: profile,
        observers: [observer],
        userSettings: userSettings,
        notificationCenter: notificationCenter,
        backgroundNotificationName: backgroundNotificationName,
        foregroundNotificationName: foregroundNotificationName
    )
    return (session, notePlayer, profile, observer, userSettings)
}

// MARK: - Task 1: Skeleton Tests

@Suite("PitchMatchingSession")
struct PitchMatchingSessionTests {

    @Test("starts in idle state")
    func startsInIdleState() async {
        let (session, _, _, _, _) = makePitchMatchingSession()
        #expect(session.state == .idle)
    }

    @Test("currentChallenge is nil initially")
    func currentChallengeNilInitially() async {
        let (session, _, _, _, _) = makePitchMatchingSession()
        #expect(session.currentChallenge == nil)
    }

    @Test("lastResult is nil initially")
    func lastResultNilInitially() async {
        let (session, _, _, _, _) = makePitchMatchingSession()
        #expect(session.lastResult == nil)
    }

    // MARK: - Task 2: Challenge Generation Tests

    @Test("challenge has note within configured range")
    func challengeNoteWithinRange() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(48)
        mockSettings.noteRangeMax = MIDINote(72)
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.referenceNote >= 48)
        #expect(challenge.referenceNote <= 72)
    }

    @Test("challenge has offset within ±100 cents")
    func challengeOffsetWithinRange() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.initialCentOffset >= -100)
        #expect(challenge.initialCentOffset <= 100)
    }

    // MARK: - Task 3: State Transition Tests

    @Test("start transitions to playingReference")
    func startTransitionsToPlayingReference() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = 5.0
        session.start()
        try await waitForState(session, .playingReference)

        #expect(session.state == .playingReference)
    }

    @Test("reference note played at correct frequency")
    func referenceNoteFrequency() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(69)
        mockSettings.noteRangeMax = MIDINote(69)
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        // A4 at 440 Hz reference = 440.0 Hz (independently verified, not using Pitch.frequency())
        #expect(notePlayer.playHistory.first != nil)
        let firstPlay = notePlayer.playHistory.first!
        #expect(abs(firstPlay.frequency - 440.0) < 0.01)
    }

    @Test("auto-transitions to playingTunable after reference")
    func autoTransitionsToPlayingTunable() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        #expect(session.state == .playingTunable)
    }

    @Test("tunable note played at offset frequency")
    func tunableNoteAtOffsetFrequency() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(69)
        mockSettings.noteRangeMax = MIDINote(69)
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        // Independent formula: ref * 2^(centOffset/1200) — note pinned to 69, ref=440
        let expectedTunableFreq = 440.0 * pow(2.0, challenge.initialCentOffset / 1200.0)

        // The second play call (handle-returning) should be the tunable note
        #expect(notePlayer.playCallCount >= 2)
        let tunableFreq = notePlayer.lastFrequency!
        #expect(abs(tunableFreq - expectedTunableFreq) < 0.01)
    }

    // MARK: - commitPitch Tests

    @Test("commitPitch stops handle")
    func commitPitchStopsHandle() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        let handle = try #require(notePlayer.lastHandle)
        session.commitPitch(0.0)
        try await Task.sleep(for: .milliseconds(50))

        #expect(handle.stopCallCount == 1)
    }

    @Test("commitPitch at center produces zero cent error")
    func commitPitchAtCenterProducesZeroCentError() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(69)
        mockSettings.noteRangeMax = MIDINote(69)
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        // Value 0.0 = reference frequency → 0 cent error
        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(abs(result.userCentError) < 0.01)
    }

    @Test("commitPitch sharp produces positive cent error")
    func commitPitchSharpCentError() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(69)
        mockSettings.noteRangeMax = MIDINote(69)
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        // Value 0.5 = 50 cents sharp
        session.commitPitch(0.5)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError > 0)
        #expect(abs(result.userCentError - 50.0) < 0.1)
    }

    @Test("commitPitch notifies observers")
    func commitPitchNotifiesObservers() async throws {
        let (session, _, _, observer, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        #expect(observer.pitchMatchingCompletedCallCount == 1)
        #expect(observer.lastResult != nil)
    }

    @Test("transitions to showingFeedback after commitPitch")
    func transitionsToShowingFeedback() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        #expect(session.state == .showingFeedback)
    }

    @Test("auto-advances from showingFeedback to playingReference")
    func autoAdvancesFromFeedback() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        // After feedback duration (~400ms), should auto-advance
        try await waitForState(session, .playingTunable, timeout: .seconds(3))
        // It went through playingReference and is now back to playingTunable (next challenge)
        #expect(session.state == .playingTunable)
    }

    // MARK: - Guard Condition Tests

    @Test("start is no-op when not idle")
    func startNoOpWhenNotIdle() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        let playCountBefore = notePlayer.playCallCount
        session.start()
        try await Task.sleep(for: .milliseconds(50))

        #expect(notePlayer.playCallCount == playCountBefore)
        #expect(session.state == .playingTunable)
    }

    @Test("commitPitch is no-op when not playingTunable")
    func commitPitchNoOpWhenNotPlayingTunable() async throws {
        let (session, _, _, observer, _) = makePitchMatchingSession()
        // Session is idle — commitPitch should do nothing
        session.commitPitch(0.0)

        #expect(session.state == .idle)
        #expect(observer.pitchMatchingCompletedCallCount == 0)
    }

    // MARK: - Cent Error Tests

    @Test("commitPitch flat produces negative cent error")
    func commitPitchFlatCentError() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(69)
        mockSettings.noteRangeMax = MIDINote(69)
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        // Value -0.5 = 50 cents flat
        session.commitPitch(-0.5)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError < 0)
        #expect(abs(result.userCentError + 50.0) < 0.1)
    }

    // MARK: - stop() Tests

    @Test("stop transitions to idle from playingTunable")
    func stopTransitionsToIdle() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        session.stop()
        #expect(session.state == .idle)
    }

    // MARK: - Task 1: Enhanced stop() Tests

    @Test("stop from playingReference stops audio and transitions to idle")
    func stopFromPlayingReference() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = 5.0
        session.start()
        try await waitForState(session, .playingReference)

        session.stop()
        #expect(session.state == .idle)
        try await Task.sleep(for: .milliseconds(50))
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("stop from playingTunable stops handle and transitions to idle")
    func stopFromPlayingTunable() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        let handle = try #require(notePlayer.lastHandle)
        session.stop()
        #expect(session.state == .idle)
        try await Task.sleep(for: .milliseconds(50))
        #expect(handle.stopCallCount >= 1)
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("stop from showingFeedback cancels feedback timer and transitions to idle")
    func stopFromShowingFeedback() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        session.stop()
        #expect(session.state == .idle)

        // Verify session does NOT advance to next challenge after stop
        try await Task.sleep(for: .milliseconds(600))
        #expect(session.state == .idle)
    }

    @Test("stop from idle is no-op")
    func stopFromIdleIsNoOp() async {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        #expect(session.state == .idle)

        session.stop()
        #expect(session.state == .idle)
        #expect(notePlayer.stopAllCallCount == 0)
    }

    @Test("stop does not notify observers")
    func stopDoesNotNotifyObservers() async throws {
        let (session, _, _, observer, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        session.stop()
        #expect(observer.pitchMatchingCompletedCallCount == 0)
    }

    @Test("stop clears currentChallenge")
    func stopClearsCurrentChallenge() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)
        #expect(session.currentChallenge != nil)

        session.stop()
        #expect(session.currentChallenge == nil)
    }

    @Test("double stop is safe")
    func doubleStopIsSafe() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start()
        try await waitForState(session, .playingTunable)

        session.stop()
        session.stop()
        #expect(session.state == .idle)
    }

    // MARK: - Pitch Adjustment Tests

    @Test("adjustPitch converts value to frequency and delegates to handle")
    func adjustPitchDelegatesToHandle() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(69)
        mockSettings.noteRangeMax = MIDINote(69)
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        let handle = try #require(notePlayer.lastHandle)

        // Value 0.0 = reference frequency (0 cent offset)
        session.adjustPitch(0.0)
        try await Task.sleep(for: .milliseconds(50))

        #expect(handle.adjustFrequencyCallCount == 1)
        // A4 at 440 Hz reference = 440.0 Hz
        #expect(abs(handle.lastAdjustedFrequency! - 440.0) < 0.01)
    }

    @Test("adjustPitch with +1.0 produces frequency 100 cents above reference")
    func adjustPitchPositiveOne() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(69)
        mockSettings.noteRangeMax = MIDINote(69)
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        let handle = try #require(notePlayer.lastHandle)
        session.adjustPitch(1.0)
        try await Task.sleep(for: .milliseconds(50))

        let expectedFreq = 440.0 * pow(2.0, 100.0 / 1200.0)
        #expect(handle.adjustFrequencyCallCount == 1)
        #expect(abs(handle.lastAdjustedFrequency! - expectedFreq) < 0.01)
    }

    @Test("adjustPitch at center adjusts to target note frequency for intervals")
    func adjustPitchCenterTargetFrequencyForInterval() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.perfectFifth]
        mockSettings.noteRangeMin = MIDINote(60)
        mockSettings.noteRangeMax = MIDINote(60)
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        let handle = try #require(notePlayer.lastHandle)
        session.adjustPitch(0.0)
        try await Task.sleep(for: .milliseconds(50))

        // Target = G4 = MIDI 67, anchor should be target frequency
        let expectedTargetFreq = TuningSystem.equalTemperament.frequency(
            for: MIDINote(67), referencePitch: .concert440)
        #expect(handle.adjustFrequencyCallCount == 1)
        #expect(abs(handle.lastAdjustedFrequency! - expectedTargetFreq.rawValue) < 0.01)
    }

    @Test("commitPitch converts and commits result")
    func commitPitchCommitsResult() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(69)
        mockSettings.noteRangeMax = MIDINote(69)
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        // Value 0.0 = reference frequency = 0 cent error
        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(abs(result.userCentError) < 0.01)
    }

    @Test("commitPitch with +0.5 produces 50 cent sharp error")
    func commitPitchHalfPositive() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(69)
        mockSettings.noteRangeMax = MIDINote(69)
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        session.commitPitch(0.5)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError > 0)
        #expect(abs(result.userCentError - 50.0) < 0.1)
    }

    @Test("adjustPitch is no-op when not playingTunable")
    func adjustPitchNoOpWhenNotPlayingTunable() async {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        // Session is idle
        session.adjustPitch(0.5)
        try? await Task.sleep(for: .milliseconds(50))

        let adjustCount = notePlayer.handleHistory.reduce(0) { $0 + $1.adjustFrequencyCallCount }
        #expect(adjustCount == 0)
    }

    // MARK: - Interval State Tests (Task 1)

    @Test("currentInterval is nil initially")
    func currentIntervalNilInitially() async {
        let (session, _, _, _, _) = makePitchMatchingSession()
        #expect(session.currentInterval == nil)
    }

    @Test("isIntervalMode is false initially")
    func isIntervalModeFalseInitially() async {
        let (session, _, _, _, _) = makePitchMatchingSession()
        #expect(session.isIntervalMode == false)
    }

    @Test("currentInterval is prime with unison intervals")
    func currentIntervalPrimeWithUnison() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.prime]
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        #expect(session.currentInterval == .prime)
        #expect(session.isIntervalMode == false)
    }

    @Test("currentInterval is perfectFifth with interval set")
    func currentIntervalPerfectFifth() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.perfectFifth]
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        #expect(session.currentInterval == .perfectFifth)
        #expect(session.isIntervalMode == true)
    }

    @Test("stop clears interval state")
    func stopClearsIntervalState() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.perfectFifth]
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)
        #expect(session.currentInterval != nil)

        session.stop()
        #expect(session.currentInterval == nil)
        #expect(session.isIntervalMode == false)
    }

    // MARK: - Interval Challenge Generation Tests (Task 3)

    @Test("generateChallenge with prime produces targetNote equal to referenceNote")
    func generateChallengePrimeTargetEqualsReference() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.prime]
        mockSettings.noteRangeMin = MIDINote(60)
        mockSettings.noteRangeMax = MIDINote(60)
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.targetNote == challenge.referenceNote)
    }

    @Test("generateChallenge with perfectFifth produces target 7 semitones above reference")
    func generateChallengePerfectFifthTarget() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.perfectFifth]
        mockSettings.noteRangeMin = MIDINote(60)
        mockSettings.noteRangeMax = MIDINote(60)
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.targetNote.rawValue == challenge.referenceNote.rawValue + 7)
    }

    @Test("generateChallenge constrains reference note range for interval")
    func generateChallengeConstrainsRangeForInterval() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.perfectFifth]
        mockSettings.noteRangeMin = MIDINote(60)
        mockSettings.noteRangeMax = MIDINote(125)
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        // Reference note must be <= 120 (127 - 7) to allow perfect fifth transposition
        #expect(challenge.referenceNote.rawValue <= 120)
        #expect(challenge.targetNote.rawValue <= 127)
    }

    // MARK: - Tuning System and Anchor Tests (Task 4)

    @Test("referenceFrequency anchor is target note frequency for intervals")
    func referenceFrequencyAnchorIsTargetFrequency() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.perfectFifth]
        mockSettings.noteRangeMin = MIDINote(60)
        mockSettings.noteRangeMax = MIDINote(60)
        mockSettings.referencePitch = .concert440
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        // Target note is C4 + perfect fifth = G4 = MIDI 67
        #expect(challenge.targetNote.rawValue == 67)
        // referenceFrequency should be the target note frequency, not the reference note frequency
        let expectedTargetFreq = TuningSystem.equalTemperament.frequency(
            for: challenge.targetNote, referencePitch: .concert440)
        let refFreq = try #require(session.referenceFrequency)
        #expect(abs(refFreq - expectedTargetFreq.rawValue) < 0.01)
    }

    @Test("tunable note is detuned from target note for intervals")
    func tunableNoteDetunedFromTargetForInterval() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.perfectFifth]
        mockSettings.noteRangeMin = MIDINote(60)
        mockSettings.noteRangeMax = MIDINote(60)
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.targetNote.rawValue == 67)

        // Tunable note should be detuned from TARGET (67), not reference (60)
        let expectedFreq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: challenge.targetNote, offset: Cents(challenge.initialCentOffset)),
            referencePitch: .concert440)

        #expect(notePlayer.playCallCount >= 2)
        let tunableFreq = notePlayer.lastFrequency!
        #expect(abs(tunableFreq - expectedFreq.rawValue) < 0.01)
    }

    @Test("commitPitch at center produces zero cent error for interval")
    func commitPitchAtCenterZeroCentErrorForInterval() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.perfectFifth]
        mockSettings.noteRangeMin = MIDINote(60)
        mockSettings.noteRangeMax = MIDINote(60)
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        // Value 0.0 = anchor frequency = target note frequency → 0 cent error
        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(abs(result.userCentError) < 0.01)
    }

    @Test("CompletedPitchMatching carries session tuningSystem")
    func completedPitchMatchingCarriesTuningSystem() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.prime]
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.tuningSystem == .equalTemperament)
    }

    @Test("start reads intervals from userSettings")
    func startReadsIntervalsFromUserSettings() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.intervals = [.majorThird, .perfectFifth]
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start()
        try await waitForState(session, .playingTunable)

        let interval = try #require(session.currentInterval)
        #expect(interval == .majorThird || interval == .perfectFifth)
    }

    // MARK: - Full Cycle Tests

    @Test("full cycle: idle → playingReference → playingTunable → showingFeedback → loop")
    func fullStateCycle() async throws {
        let (session, _, _, observer, _) = makePitchMatchingSession()

        #expect(session.state == .idle)

        session.start()
        try await waitForState(session, .playingTunable)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)
        #expect(observer.pitchMatchingCompletedCallCount == 1)

        // Wait for auto-advance to next challenge
        try await waitForState(session, .playingTunable, timeout: .seconds(3))

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)
        #expect(observer.pitchMatchingCompletedCallCount == 2)
    }
}

// MARK: - Audio Interruption and Lifecycle Tests

@Suite("PitchMatchingSession Audio Interruption Tests", .serialized)
struct PitchMatchingSessionAudioInterruptionTests {

    // MARK: - Audio Interruption Tests

    @Test("Audio interruption began stops from playingTunable")
    func audioInterruptionBeganStopsFromPlayingTunable() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start()
        try await waitForState(session, .playingTunable)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption ended does not restart")
    func audioInterruptionEndedDoesNotRestart() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start()
        try await waitForState(session, .playingTunable)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try await waitForState(session, .idle)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]
        )

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .idle)
    }

    @Test("Nil interruption type handled gracefully")
    func nilInterruptionTypeHandledGracefully() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start()
        try await waitForState(session, .playingTunable)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: nil
        )

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .playingTunable)
    }

    @Test("Audio interruption on idle is safe")
    func audioInterruptionOnIdleIsSafe() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        #expect(session.state == .idle)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .idle)
    }

    @Test("Audio interruption began stops from playingReference")
    func audioInterruptionBeganStopsFromPlayingReference() async throws {
        let nc = NotificationCenter()
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = 5.0
        session.start()
        try await waitForState(session, .playingReference)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption began stops from showingFeedback")
    func audioInterruptionBeganStopsFromShowingFeedback() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start()
        try await waitForState(session, .playingTunable)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    // MARK: - Route Change Tests

    @Test("Route change oldDeviceUnavailable stops session")
    func routeChangeOldDeviceUnavailableStops() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start()
        try await waitForState(session, .playingTunable)

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Non-stop route changes continue session")
    func nonStopRouteChangesContinue() async throws {
        let nonStopReasons: [UInt?] = [
            AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue,
            AVAudioSession.RouteChangeReason.categoryChange.rawValue,
            nil
        ]

        for reason in nonStopReasons {
            let nc = NotificationCenter()
            let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
            session.start()
            try await waitForState(session, .playingTunable)

            let userInfo: [AnyHashable: Any]? = reason.map { [AVAudioSessionRouteChangeReasonKey: $0] }
            nc.post(
                name: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                userInfo: userInfo
            )

            try await Task.sleep(for: .milliseconds(50))
            await Task.yield()
            #expect(session.state == .playingTunable, "Session should continue for route change reason \(String(describing: reason))")
            session.stop()
        }
    }

    @Test("Route change on idle is safe")
    func routeChangeOnIdleIsSafe() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        #expect(session.state == .idle)

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .idle)
    }

    // MARK: - Background Notification Tests

    @Test("Background notification stops from playingTunable")
    func backgroundNotificationStopsFromPlayingTunable() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start()
        try await waitForState(session, .playingTunable)

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Background notification on idle is safe")
    func backgroundNotificationOnIdleIsSafe() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        #expect(session.state == .idle)

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .idle)
    }

    // MARK: - Restart Tests

    @Test("Training can restart after interruption stop")
    func canRestartAfterInterruptionStop() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start()
        try await waitForState(session, .playingTunable)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try await waitForState(session, .idle)

        session.start()
        try await waitForState(session, .playingTunable)
        #expect(session.state == .playingTunable)
    }

    @Test("Training can restart after route change stop")
    func canRestartAfterRouteChangeStop() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start()
        try await waitForState(session, .playingTunable)

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )
        try await waitForState(session, .idle)

        session.start()
        try await waitForState(session, .playingTunable)
        #expect(session.state == .playingTunable)
    }

    @Test("Training can restart after background stop")
    func canRestartAfterBackgroundStop() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start()
        try await waitForState(session, .playingTunable)

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        try await waitForState(session, .idle)

        session.start()
        try await waitForState(session, .playingTunable)
        #expect(session.state == .playingTunable)
    }
}
