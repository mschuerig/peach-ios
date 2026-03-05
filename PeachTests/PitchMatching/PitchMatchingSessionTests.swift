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

/// Transition session from awaitingSliderTouch to playingTunable with handle assigned
func transitionToPlayingTunable(_ session: PitchMatchingSession) async throws {
    try await waitForState(session, .awaitingSliderTouch)
    session.adjustPitch(0.0)
    try await Task.sleep(for: .milliseconds(50))
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
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(72))
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.referenceNote >= 48)
        #expect(challenge.referenceNote <= 72)
    }

    @Test("challenge has offset within ±20 cents")
    func challengeOffsetWithinRange() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.initialCentOffset >= -20)
        #expect(challenge.initialCentOffset <= 20)
    }

    // MARK: - Task 3: State Transition Tests

    @Test("start transitions to playingReference")
    func startTransitionsToPlayingReference() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = 5.0
        session.start(intervals: [.prime])
        try await waitForState(session, .playingReference)

        #expect(session.state == .playingReference)
    }

    @Test("reference note played at correct frequency")
    func referenceNoteFrequency() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81))
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        let challenge = try #require(session.currentChallenge)
        let expectedFreq = TuningSystem.equalTemperament.frequency(for: challenge.referenceNote, referencePitch: .concert440)
        #expect(notePlayer.playHistory.first != nil)
        let firstPlay = notePlayer.playHistory.first!
        #expect(abs(firstPlay.frequency - expectedFreq.rawValue) < 0.01)
    }

    @Test("transitions to awaitingSliderTouch after reference")
    func transitionsToAwaitingSliderTouchAfterReference() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        #expect(session.state == .awaitingSliderTouch)
    }

    @Test("no tunable note played in awaitingSliderTouch")
    func noTunableNoteInAwaitingSliderTouch() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        // Only the reference note (fire-and-forget) should have been played
        // Note: mock's fire-and-forget play internally calls handle-returning play, so playCallCount is 1
        #expect(notePlayer.playCallCount == 1)
        #expect(notePlayer.handleHistory.count == 1)
    }

    @Test("adjustPitch from awaitingSliderTouch transitions to playingTunable and starts note")
    func adjustPitchFromAwaitingSliderTouchStartsNote() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
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
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81))
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        let challenge = try #require(session.currentChallenge)
        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        // Slider at 0 means "accept detuned pitch as-is" — error should equal initialCentOffset, not 0
        #expect(abs(result.userCentError.rawValue - challenge.initialCentOffset.rawValue) < 0.01)
        // Only reference note played — no tunable note started (would be immediately orphaned)
        #expect(notePlayer.playCallCount == 1)
    }

    @Test("stop from awaitingSliderTouch transitions to idle with no tunable note")
    func stopFromAwaitingSliderTouch() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        session.stop()
        #expect(session.state == .idle)
        #expect(session.currentChallenge == nil)
        // Only reference note was played, no tunable note
        #expect(notePlayer.playCallCount == 1)
    }

    @Test("tunable note played at offset frequency")
    func tunableNoteAtOffsetFrequency() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81))
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        let challenge = try #require(session.currentChallenge)
        let baseFreq = TuningSystem.equalTemperament.frequency(for: challenge.referenceNote, referencePitch: .concert440)
        let expectedTunableFreq = baseFreq.rawValue * pow(2.0, challenge.initialCentOffset.rawValue / 1200.0)

        // The second play call (handle-returning) should be the tunable note
        #expect(notePlayer.playCallCount >= 2)
        let tunableFreq = notePlayer.lastFrequency!
        #expect(abs(tunableFreq - expectedTunableFreq) < 0.01)
    }

    // MARK: - commitPitch Tests

    @Test("commitPitch stops handle")
    func commitPitchStopsHandle() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        let handle = try #require(notePlayer.lastHandle)
        session.commitPitch(0.0)
        try await Task.sleep(for: .milliseconds(50))

        #expect(handle.stopCallCount == 1)
    }

    @Test("commitPitch at correcting slider value produces zero cent error")
    func commitPitchAtCenterProducesZeroCentError() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81))
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        let challenge = try #require(session.currentChallenge)
        // Slider value that cancels initialCentOffset → 0 cent error
        let correctingValue = -challenge.initialCentOffset.rawValue / 20.0
        session.commitPitch(correctingValue)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(abs(result.userCentError.rawValue) < 0.01)
    }

    @Test("commitPitch sharp produces positive cent error")
    func commitPitchSharpCentError() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81))
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        let challenge = try #require(session.currentChallenge)
        // Slider value that produces exactly +10 cents: initialCentOffset + value * 20 = 10
        let value = (10.0 - challenge.initialCentOffset.rawValue) / 20.0
        session.commitPitch(value)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError > 0)
        #expect(abs(result.userCentError.rawValue - 10.0) < 0.1)
    }

    @Test("commitPitch notifies observers")
    func commitPitchNotifiesObservers() async throws {
        let (session, _, _, observer, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        #expect(observer.pitchMatchingCompletedCallCount == 1)
        #expect(observer.lastResult != nil)
    }

    @Test("transitions to showingFeedback after commitPitch")
    func transitionsToShowingFeedback() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        #expect(session.state == .showingFeedback)
    }

    @Test("auto-advances from showingFeedback to awaitingSliderTouch")
    func autoAdvancesFromFeedback() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        // After feedback duration (~400ms), should auto-advance to next challenge
        try await waitForState(session, .awaitingSliderTouch, timeout: .seconds(3))
        #expect(session.state == .awaitingSliderTouch)
    }

    // MARK: - Guard Condition Tests

    @Test("start is no-op when not idle")
    func startNoOpWhenNotIdle() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        let playCountBefore = notePlayer.playCallCount
        session.start(intervals: [.prime])
        try await Task.sleep(for: .milliseconds(50))

        #expect(notePlayer.playCallCount == playCountBefore)
        #expect(session.state == .awaitingSliderTouch)
    }

    @Test("commitPitch is no-op when idle")
    func commitPitchNoOpWhenIdle() async throws {
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
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81))
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        let challenge = try #require(session.currentChallenge)
        // Slider value that produces exactly -10 cents: initialCentOffset + value * 20 = -10
        let value = (-10.0 - challenge.initialCentOffset.rawValue) / 20.0
        session.commitPitch(value)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError < 0)
        #expect(abs(result.userCentError.rawValue + 10.0) < 0.1)
    }

    // MARK: - stop() Tests

    @Test("stop transitions to idle from awaitingSliderTouch")
    func stopTransitionsToIdle() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        session.stop()
        #expect(session.state == .idle)
    }

    // MARK: - Task 1: Enhanced stop() Tests

    @Test("stop from playingReference stops audio and transitions to idle")
    func stopFromPlayingReference() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = 5.0
        session.start(intervals: [.prime])
        try await waitForState(session, .playingReference)

        session.stop()
        #expect(session.state == .idle)
        try await Task.sleep(for: .milliseconds(50))
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("stop from playingTunable stops handle and transitions to idle")
    func stopFromPlayingTunable() async throws {
        let (session, notePlayer, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
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
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

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
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        session.stop()
        #expect(observer.pitchMatchingCompletedCallCount == 0)
    }

    @Test("stop clears currentChallenge")
    func stopClearsCurrentChallenge() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.currentChallenge != nil)

        session.stop()
        #expect(session.currentChallenge == nil)
    }

    @Test("double stop is safe")
    func doubleStopIsSafe() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        session.stop()
        session.stop()
        #expect(session.state == .idle)
    }

    // MARK: - Pitch Adjustment Tests

    @Test("adjustPitch converts value to frequency and delegates to handle")
    func adjustPitchDelegatesToHandle() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81))
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        let challenge = try #require(session.currentChallenge)
        let handle = try #require(notePlayer.lastHandle)
        let adjustCountBefore = handle.adjustFrequencyCallCount

        // Slider value that cancels initialCentOffset → exact target frequency
        let correctingValue = -challenge.initialCentOffset.rawValue / 20.0
        session.adjustPitch(correctingValue)
        try await Task.sleep(for: .milliseconds(50))

        let expectedFreq = TuningSystem.equalTemperament.frequency(for: challenge.targetNote, referencePitch: .concert440)
        #expect(handle.adjustFrequencyCallCount == adjustCountBefore + 1)
        #expect(abs(handle.lastAdjustedFrequency! - expectedFreq.rawValue) < 0.01)
    }

    @Test("adjustPitch with +1.0 produces frequency (initialCentOffset + 20) cents above reference")
    func adjustPitchPositiveOne() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81))
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        let challenge = try #require(session.currentChallenge)
        let handle = try #require(notePlayer.lastHandle)
        let adjustCountBefore = handle.adjustFrequencyCallCount
        session.adjustPitch(1.0)
        try await Task.sleep(for: .milliseconds(50))

        let targetFreq = TuningSystem.equalTemperament.frequency(for: challenge.targetNote, referencePitch: .concert440).rawValue
        let totalCentOffset = challenge.initialCentOffset.rawValue + 20.0
        let expectedFreq = targetFreq * pow(2.0, totalCentOffset / 1200.0)
        #expect(handle.adjustFrequencyCallCount == adjustCountBefore + 1)
        #expect(abs(handle.lastAdjustedFrequency! - expectedFreq) < 0.01)
    }

    @Test("adjustPitch at correcting value adjusts to target note frequency for intervals")
    func adjustPitchCenterTargetFrequencyForInterval() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.up(.perfectFifth)])
        try await transitionToPlayingTunable(session)

        let challenge = try #require(session.currentChallenge)
        let handle = try #require(notePlayer.lastHandle)
        let adjustCountBefore = handle.adjustFrequencyCallCount
        // Slider value that cancels initialCentOffset → exact target frequency
        let correctingValue = -challenge.initialCentOffset.rawValue / 20.0
        session.adjustPitch(correctingValue)
        try await Task.sleep(for: .milliseconds(50))

        let expectedTargetFreq = TuningSystem.equalTemperament.frequency(
            for: challenge.targetNote, referencePitch: .concert440)
        #expect(handle.adjustFrequencyCallCount == adjustCountBefore + 1)
        #expect(abs(handle.lastAdjustedFrequency! - expectedTargetFreq.rawValue) < 0.01)
    }

    @Test("commitPitch at correcting value commits result with zero cent error")
    func commitPitchCommitsResult() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81))
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        let challenge = try #require(session.currentChallenge)
        // Slider value that cancels initialCentOffset → 0 cent error
        let correctingValue = -challenge.initialCentOffset.rawValue / 20.0
        session.commitPitch(correctingValue)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(abs(result.userCentError.rawValue) < 0.01)
    }

    @Test("commitPitch produces 10 cent sharp error at correct slider value")
    func commitPitchHalfPositive() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(69), upperBound: MIDINote(81))
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        let challenge = try #require(session.currentChallenge)
        // Slider value that produces exactly +10 cents: initialCentOffset + value * 20 = 10
        let value = (10.0 - challenge.initialCentOffset.rawValue) / 20.0
        session.commitPitch(value)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError > 0)
        #expect(abs(result.userCentError.rawValue - 10.0) < 0.1)
    }

    @Test("adjustPitch is no-op when idle")
    func adjustPitchNoOpWhenIdle() async {
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
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        #expect(session.currentInterval == .prime)
        #expect(session.isIntervalMode == false)
    }

    @Test("currentInterval is perfectFifth with interval set")
    func currentIntervalPerfectFifth() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.up(.perfectFifth)])
        try await waitForState(session, .awaitingSliderTouch)

        #expect(session.currentInterval == .up(.perfectFifth))
        #expect(session.isIntervalMode == true)
    }

    @Test("stop clears interval state")
    func stopClearsIntervalState() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.up(.perfectFifth)])
        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.currentInterval != nil)

        session.stop()
        #expect(session.currentInterval == nil)
        #expect(session.isIntervalMode == false)
    }

    // MARK: - Interval Challenge Generation Tests (Task 3)

    @Test("generateChallenge with prime produces targetNote equal to referenceNote")
    func generateChallengePrimeTargetEqualsReference() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.targetNote == challenge.referenceNote)
    }

    @Test("generateChallenge with perfectFifth produces target 7 semitones above reference")
    func generateChallengePerfectFifthTarget() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.up(.perfectFifth)])
        try await waitForState(session, .awaitingSliderTouch)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.targetNote.rawValue == challenge.referenceNote.rawValue + 7)
    }

    @Test("generateChallenge constrains reference note range for interval")
    func generateChallengeConstrainsRangeForInterval() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(125))
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.up(.perfectFifth)])
        try await waitForState(session, .awaitingSliderTouch)

        let challenge = try #require(session.currentChallenge)
        // Reference note must be <= 120 (127 - 7) to allow perfect fifth transposition
        #expect(challenge.referenceNote.rawValue <= 120)
        #expect(challenge.targetNote.rawValue <= 127)
    }

    @Test("generateChallenge with downward perfectFifth produces target 7 semitones below reference")
    func generateChallengeDownwardPerfectFifthTarget() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.down(.perfectFifth)])
        try await waitForState(session, .awaitingSliderTouch)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.targetNote.rawValue == challenge.referenceNote.rawValue - 7)
    }

    @Test("generateChallenge constrains reference note minimum for downward interval")
    func generateChallengeConstrainsRangeForDownwardInterval() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(0), upperBound: MIDINote(84))
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.down(.perfectFifth)])
        try await waitForState(session, .awaitingSliderTouch)

        let challenge = try #require(session.currentChallenge)
        // Reference note must be >= 7 so target (ref - 7) stays >= 0
        #expect(challenge.referenceNote.rawValue >= 7)
        #expect(challenge.targetNote.rawValue >= 0)
    }

    // MARK: - Tuning System and Anchor Tests (Task 4)

    @Test("referenceFrequency anchor is target note frequency for intervals")
    func referenceFrequencyAnchorIsTargetFrequency() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
        mockSettings.referencePitch = .concert440
        let (session, _, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.up(.perfectFifth)])
        try await waitForState(session, .awaitingSliderTouch)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.targetNote.rawValue == challenge.referenceNote.rawValue + 7)
        // referenceFrequency should be the target note frequency, not the reference note frequency
        let expectedTargetFreq = TuningSystem.equalTemperament.frequency(
            for: challenge.targetNote, referencePitch: .concert440)
        let refFreq = try #require(session.referenceFrequency)
        #expect(abs(refFreq.rawValue - expectedTargetFreq.rawValue) < 0.01)
    }

    @Test("tunable note is detuned from target note for intervals")
    func tunableNoteDetunedFromTargetForInterval() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
        mockSettings.referencePitch = .concert440
        let (session, notePlayer, _, _, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.up(.perfectFifth)])
        try await transitionToPlayingTunable(session)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.targetNote.rawValue == challenge.referenceNote.rawValue + 7)

        // Tunable note should be detuned from TARGET (67), not reference (60)
        let expectedFreq = TuningSystem.equalTemperament.frequency(
            for: DetunedMIDINote(note: challenge.targetNote, offset: challenge.initialCentOffset),
            referencePitch: .concert440)

        #expect(notePlayer.playCallCount >= 2)
        let tunableFreq = notePlayer.lastFrequency!
        #expect(abs(tunableFreq - expectedFreq.rawValue) < 0.01)
    }

    @Test("commitPitch at correcting value produces zero cent error for interval")
    func commitPitchAtCenterZeroCentErrorForInterval() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRange = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
        mockSettings.referencePitch = .concert440
        let (session, _, _, observer, _) = makePitchMatchingSession(userSettings: mockSettings)
        session.start(intervals: [.up(.perfectFifth)])
        try await transitionToPlayingTunable(session)

        let challenge = try #require(session.currentChallenge)
        // Slider value that cancels initialCentOffset → 0 cent error
        let correctingValue = -challenge.initialCentOffset.rawValue / 20.0
        session.commitPitch(correctingValue)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(abs(result.userCentError.rawValue) < 0.01)
    }

    @Test("CompletedPitchMatching carries session tuningSystem")
    func completedPitchMatchingCarriesTuningSystem() async throws {
        let (session, _, _, observer, _) = makePitchMatchingSession()
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.tuningSystem == .equalTemperament)
    }

    @Test("start uses intervals parameter for session")
    func startUsesIntervalsParameter() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.up(.majorThird), .up(.perfectFifth)])
        try await waitForState(session, .awaitingSliderTouch)

        let interval = try #require(session.currentInterval)
        #expect(interval == .up(.majorThird) || interval == .up(.perfectFifth))
    }

    @Test("start with perfectFifth sets currentInterval to perfectFifth")
    func startWithPerfectFifthSetsCurrentInterval() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        session.start(intervals: [.up(.perfectFifth)])
        try await waitForState(session, .awaitingSliderTouch)

        #expect(session.currentInterval == .up(.perfectFifth))
        #expect(session.isIntervalMode)
        session.stop()
    }

    @Test("start with multiple intervals picks from the provided set")
    func startWithMultipleIntervals() async throws {
        let (session, _, _, _, _) = makePitchMatchingSession()
        let intervals: Set<DirectedInterval> = [.prime, .up(.perfectFifth)]
        session.start(intervals: intervals)
        try await waitForState(session, .awaitingSliderTouch)

        let interval = try #require(session.currentInterval)
        #expect(intervals.contains(interval))
        session.stop()
    }

    // MARK: - Full Cycle Tests

    @Test("full cycle: idle → playingReference → awaitingSliderTouch → playingTunable → showingFeedback → loop")
    func fullStateCycle() async throws {
        let (session, _, _, observer, _) = makePitchMatchingSession()

        #expect(session.state == .idle)

        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.state == .awaitingSliderTouch)

        session.adjustPitch(0.0)
        #expect(session.state == .playingTunable)
        try await Task.sleep(for: .milliseconds(50))

        session.commitPitch(0.0)
        try await waitForState(session, .showingFeedback)
        #expect(observer.pitchMatchingCompletedCallCount == 1)

        // Wait for auto-advance to next challenge
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
        let (session, _, _, _, _) = makePitchMatchingSession()
        #expect(session.sessionTuningSystem == .equalTemperament)
    }

    @Test("sessionTuningSystem reflects userSettings after start")
    func sessionTuningSystemFromSettings() async {
        let (session, notePlayer, _, _, mockSettings) = makePitchMatchingSession()
        notePlayer.instantPlayback = true
        mockSettings.tuningSystem = .justIntonation
        session.start(intervals: [.prime])
        await Task.yield()
        #expect(session.sessionTuningSystem == .justIntonation)
        session.stop()
    }

    @Test("sessionTuningSystem resets to equalTemperament after stop")
    func sessionTuningSystemResetsOnStop() async {
        let (session, notePlayer, _, _, mockSettings) = makePitchMatchingSession()
        notePlayer.instantPlayback = true
        mockSettings.tuningSystem = .justIntonation
        session.start(intervals: [.prime])
        await Task.yield()
        session.stop()
        #expect(session.sessionTuningSystem == .equalTemperament)
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
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption began stops from awaitingSliderTouch")
    func audioInterruptionBeganStopsFromAwaitingSliderTouch() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

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
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

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
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: nil
        )

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .awaitingSliderTouch)
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
        session.start(intervals: [.prime])
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
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

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
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

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
            session.start(intervals: [.prime])
            try await waitForState(session, .awaitingSliderTouch)

            let userInfo: [AnyHashable: Any]? = reason.map { [AVAudioSessionRouteChangeReasonKey: $0] }
            nc.post(
                name: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                userInfo: userInfo
            )

            try await Task.sleep(for: .milliseconds(50))
            await Task.yield()
            #expect(session.state == .awaitingSliderTouch, "Session should continue for route change reason \(String(describing: reason))")
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
        session.start(intervals: [.prime])
        try await transitionToPlayingTunable(session)

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Background notification stops from awaitingSliderTouch")
    func backgroundNotificationStopsFromAwaitingSliderTouch() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

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
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try await waitForState(session, .idle)

        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.state == .awaitingSliderTouch)
    }

    @Test("Training can restart after route change stop")
    func canRestartAfterRouteChangeStop() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )
        try await waitForState(session, .idle)

        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.state == .awaitingSliderTouch)
    }

    @Test("Training can restart after background stop")
    func canRestartAfterBackgroundStop() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        try await waitForState(session, .idle)

        session.start(intervals: [.prime])
        try await waitForState(session, .awaitingSliderTouch)
        #expect(session.state == .awaitingSliderTouch)
    }


}
