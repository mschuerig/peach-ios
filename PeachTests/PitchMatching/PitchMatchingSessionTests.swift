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
    settingsOverride: TrainingSettings? = TrainingSettings(),
    noteDurationOverride: TimeInterval? = 0.0,
    notificationCenter: NotificationCenter = .default
) -> (session: PitchMatchingSession, notePlayer: MockNotePlayer, profile: MockPitchMatchingProfile, observer: MockPitchMatchingObserver) {
    let notePlayer = MockNotePlayer()
    let profile = MockPitchMatchingProfile()
    let observer = MockPitchMatchingObserver()
    let session = PitchMatchingSession(
        notePlayer: notePlayer,
        profile: profile,
        observers: [observer],
        settingsOverride: settingsOverride,
        noteDurationOverride: noteDurationOverride,
        notificationCenter: notificationCenter
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

    @Test("currentChallenge is nil initially")
    func currentChallengeNilInitially() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.currentChallenge == nil)
    }

    @Test("lastResult is nil initially")
    func lastResultNilInitially() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.lastResult == nil)
    }

    // MARK: - Task 2: Challenge Generation Tests

    @Test("challenge has note within configured range")
    func challengeNoteWithinRange() async throws {
        let settings = TrainingSettings(noteRangeMin: 48, noteRangeMax: 72)
        let (session, _, _, _) = makePitchMatchingSession(settingsOverride: settings)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.referenceNote >= 48)
        #expect(challenge.referenceNote <= 72)
    }

    @Test("challenge has offset within ±100 cents")
    func challengeOffsetWithinRange() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.initialCentOffset >= -100)
        #expect(challenge.initialCentOffset <= 100)
    }

    // MARK: - Task 3: State Transition Tests

    @Test("startPitchMatching transitions to playingReference")
    func startTransitionsToPlayingReference() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = 5.0
        session.startPitchMatching()
        try await waitForState(session, .playingReference)

        #expect(session.state == .playingReference)
    }

    @Test("reference note played at correct frequency")
    func referenceNoteFrequency() async throws {
        let settings = TrainingSettings(noteRangeMin: 69, noteRangeMax: 69, referencePitch: 440.0)
        let (session, notePlayer, _, _) = makePitchMatchingSession(settingsOverride: settings)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let expectedFrequency = try FrequencyCalculation.frequency(midiNote: 69, referencePitch: 440.0)
        #expect(notePlayer.playHistory.first != nil)
        let firstPlay = notePlayer.playHistory.first!
        #expect(abs(firstPlay.frequency - expectedFrequency) < 0.01)
    }

    @Test("auto-transitions to playingTunable after reference")
    func autoTransitionsToPlayingTunable() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        #expect(session.state == .playingTunable)
    }

    @Test("tunable note played at offset frequency")
    func tunableNoteAtOffsetFrequency() async throws {
        let settings = TrainingSettings(noteRangeMin: 69, noteRangeMax: 69, referencePitch: 440.0)
        let (session, notePlayer, _, _) = makePitchMatchingSession(settingsOverride: settings)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        let expectedTunableFreq = try FrequencyCalculation.frequency(
            midiNote: challenge.referenceNote,
            cents: challenge.initialCentOffset,
            referencePitch: 440.0
        )

        // The second play call (handle-returning) should be the tunable note
        #expect(notePlayer.playCallCount >= 2)
        let tunableFreq = notePlayer.lastFrequency!
        #expect(abs(tunableFreq - expectedTunableFreq) < 0.01)
    }

    // MARK: - Task 4: adjustFrequency and commitResult Tests

    @Test("adjustFrequency delegates to handle")
    func adjustFrequencyDelegatesToHandle() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let handle = try #require(notePlayer.lastHandle)
        session.adjustFrequency(450.0)
        try await Task.sleep(for: .milliseconds(50))

        #expect(handle.adjustFrequencyCallCount == 1)
        #expect(handle.lastAdjustedFrequency == 450.0)
    }

    @Test("commitResult stops handle")
    func commitResultStopsHandle() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let handle = try #require(notePlayer.lastHandle)
        session.commitResult(userFrequency: 440.0)
        try await Task.sleep(for: .milliseconds(50))

        #expect(handle.stopCallCount == 1)
    }

    @Test("commitResult computes correct cent error")
    func commitResultComputesCentError() async throws {
        let settings = TrainingSettings(noteRangeMin: 69, noteRangeMax: 69, referencePitch: 440.0)
        let (session, _, _, observer) = makePitchMatchingSession(settingsOverride: settings)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        // User sings exactly at reference → 0 cent error
        let referenceFreq = try FrequencyCalculation.frequency(midiNote: 69, referencePitch: 440.0)
        session.commitResult(userFrequency: referenceFreq)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(abs(result.userCentError) < 0.01)
    }

    @Test("commitResult computes positive cent error when sharp")
    func commitResultSharpCentError() async throws {
        let settings = TrainingSettings(noteRangeMin: 69, noteRangeMax: 69, referencePitch: 440.0)
        let (session, _, _, observer) = makePitchMatchingSession(settingsOverride: settings)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        // User plays sharp (higher frequency)
        let sharpFreq = 440.0 * pow(2.0, 50.0 / 1200.0) // 50 cents sharp
        session.commitResult(userFrequency: sharpFreq)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError > 0)
        #expect(abs(result.userCentError - 50.0) < 0.1)
    }

    @Test("commitResult notifies observers")
    func commitResultNotifiesObservers() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.commitResult(userFrequency: 440.0)
        try await waitForState(session, .showingFeedback)

        #expect(observer.pitchMatchingCompletedCallCount == 1)
        #expect(observer.lastResult != nil)
    }

    @Test("transitions to showingFeedback after commitResult")
    func transitionsToShowingFeedback() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.commitResult(userFrequency: 440.0)
        try await waitForState(session, .showingFeedback)

        #expect(session.state == .showingFeedback)
    }

    @Test("auto-advances from showingFeedback to playingReference")
    func autoAdvancesFromFeedback() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.commitResult(userFrequency: 440.0)
        try await waitForState(session, .showingFeedback)

        // After feedback duration (~400ms), should auto-advance
        try await waitForState(session, .playingTunable, timeout: .seconds(3))
        // It went through playingReference and is now back to playingTunable (next challenge)
        #expect(session.state == .playingTunable)
    }

    // MARK: - Guard Condition Tests

    @Test("startPitchMatching is no-op when not idle")
    func startPitchMatchingNoOpWhenNotIdle() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let playCountBefore = notePlayer.playCallCount
        session.startPitchMatching()
        try await Task.sleep(for: .milliseconds(50))

        #expect(notePlayer.playCallCount == playCountBefore)
        #expect(session.state == .playingTunable)
    }

    @Test("adjustFrequency is no-op when not playingTunable")
    func adjustFrequencyNoOpWhenNotPlayingTunable() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = 5.0
        session.startPitchMatching()
        try await waitForState(session, .playingReference)

        session.adjustFrequency(450.0)
        try await Task.sleep(for: .milliseconds(50))

        // Guard prevents adjustFrequency during playingReference
        let adjustCount = notePlayer.handleHistory.reduce(0) { $0 + $1.adjustFrequencyCallCount }
        #expect(adjustCount == 0)
    }

    @Test("commitResult is no-op when not playingTunable")
    func commitResultNoOpWhenNotPlayingTunable() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        // Session is idle — commitResult should do nothing
        session.commitResult(userFrequency: 440.0)

        #expect(session.state == .idle)
        #expect(observer.pitchMatchingCompletedCallCount == 0)
    }

    // MARK: - Cent Error Tests

    @Test("commitResult computes negative cent error when flat")
    func commitResultFlatCentError() async throws {
        let settings = TrainingSettings(noteRangeMin: 69, noteRangeMax: 69, referencePitch: 440.0)
        let (session, _, _, observer) = makePitchMatchingSession(settingsOverride: settings)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        // User plays flat (lower frequency) — 50 cents flat
        let flatFreq = 440.0 * pow(2.0, -50.0 / 1200.0)
        session.commitResult(userFrequency: flatFreq)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError < 0)
        #expect(abs(result.userCentError + 50.0) < 0.1)
    }

    // MARK: - stop() Tests

    @Test("stop transitions to idle from playingTunable")
    func stopTransitionsToIdle() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.stop()
        #expect(session.state == .idle)
    }

    // MARK: - Task 1: Enhanced stop() Tests

    @Test("stop from playingReference stops audio and transitions to idle")
    func stopFromPlayingReference() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = 5.0
        session.startPitchMatching()
        try await waitForState(session, .playingReference)

        session.stop()
        #expect(session.state == .idle)
        try await Task.sleep(for: .milliseconds(50))
        #expect(notePlayer.stopAllCallCount >= 1)
    }

    @Test("stop from playingTunable stops handle and transitions to idle")
    func stopFromPlayingTunable() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
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
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.commitResult(userFrequency: 440.0)
        try await waitForState(session, .showingFeedback)

        session.stop()
        #expect(session.state == .idle)

        // Verify session does NOT advance to next challenge after stop
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
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.stop()
        #expect(observer.pitchMatchingCompletedCallCount == 0)
    }

    @Test("stop clears currentChallenge")
    func stopClearsCurrentChallenge() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)
        #expect(session.currentChallenge != nil)

        session.stop()
        #expect(session.currentChallenge == nil)
    }

    @Test("double stop is safe")
    func doubleStopIsSafe() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.stop()
        session.stop()
        #expect(session.state == .idle)
    }

    // MARK: - Full Cycle Tests

    @Test("full cycle: idle → playingReference → playingTunable → showingFeedback → loop")
    func fullStateCycle() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()

        #expect(session.state == .idle)

        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.commitResult(userFrequency: 440.0)
        try await waitForState(session, .showingFeedback)
        #expect(observer.pitchMatchingCompletedCallCount == 1)

        // Wait for auto-advance to next challenge
        try await waitForState(session, .playingTunable, timeout: .seconds(3))

        session.commitResult(userFrequency: 440.0)
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
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.startPitchMatching()
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
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.startPitchMatching()
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
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.startPitchMatching()
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
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
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
        let (session, notePlayer, _, _) = makePitchMatchingSession(notificationCenter: nc)
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = 5.0
        session.startPitchMatching()
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
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.commitResult(userFrequency: 440.0)
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
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.startPitchMatching()
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
            let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
            session.startPitchMatching()
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
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
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
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Background notification on idle is safe")
    func backgroundNotificationOnIdleIsSafe() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
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
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try await waitForState(session, .idle)

        session.startPitchMatching()
        try await waitForState(session, .playingTunable)
        #expect(session.state == .playingTunable)
    }

    @Test("Training can restart after route change stop")
    func canRestartAfterRouteChangeStop() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )
        try await waitForState(session, .idle)

        session.startPitchMatching()
        try await waitForState(session, .playingTunable)
        #expect(session.state == .playingTunable)
    }

    @Test("Training can restart after background stop")
    func canRestartAfterBackgroundStop() async throws {
        let nc = NotificationCenter()
        let (session, _, _, _) = makePitchMatchingSession(notificationCenter: nc)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        nc.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        try await waitForState(session, .idle)

        session.startPitchMatching()
        try await waitForState(session, .playingTunable)
        #expect(session.state == .playingTunable)
    }
}
