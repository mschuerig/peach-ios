import Observation
import SwiftUI
import Testing
@testable import Peach

@Suite("TrainingLifecycleCoordinator")
struct TrainingLifecycleCoordinatorTests {

    // MARK: - Scene Phase

    @Test("iOS: stops active session on background")
    func backgroundStopsActiveSession() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive)

        coordinator.handleScenePhase(old: .active, new: .background)

        #expect(coordinator.isTrainingActive == false)
    }

    @Test("does not crash when no training destination")
    func backgroundWithNoTrainingDestination() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())

        coordinator.handleScenePhase(old: .active, new: .background)
        // No crash — nil currentTrainingDestination is safe
    }

    @Test("iOS: does not stop session on inactive")
    func iosDoesNotStopOnInactive() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive)

        coordinator.handleScenePhase(old: .active, new: .inactive)

        #expect(coordinator.isTrainingActive)
    }

    @Test("macOS: stops session on inactive")
    func macosStopsOnInactive() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        #expect(coordinator.isTrainingActive)

        coordinator.handleScenePhase(old: .active, new: .inactive)

        #expect(coordinator.isTrainingActive == false)
    }

    @Test("macOS: stops session on background")
    func macosStopsOnBackground() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        #expect(coordinator.isTrainingActive)

        coordinator.handleScenePhase(old: .active, new: .background)

        #expect(coordinator.isTrainingActive == false)
    }

    // MARK: - Auto-Restart on Foreground Return

    @Test("iOS: auto-restarts training when returning to active with training destination")
    func iosAutoRestartsOnForeground() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        // Simulate being on a training screen that was stopped
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.stopCurrentSession()

        #expect(coordinator.isTrainingActive == false)

        coordinator.handleScenePhase(old: .background, new: .active)

        #expect(coordinator.isTrainingActive)
    }

    @Test("macOS: does not auto-restart training when returning to active")
    func macosDoesNotAutoRestartOnForeground() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        // macOS doesn't auto-start, so manually start then stop
        coordinator.startCurrentSession()
        coordinator.stopCurrentSession()

        #expect(coordinator.isTrainingActive == false)

        coordinator.handleScenePhase(old: .inactive, new: .active)

        #expect(coordinator.isTrainingActive == false)
    }

    // MARK: - macOS App Activation

    @Test("handleAppDeactivated stops current session")
    func handleAppDeactivatedStopsSession() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        #expect(coordinator.isTrainingActive)

        coordinator.handleAppDeactivated()

        #expect(coordinator.isTrainingActive == false)
    }

    @Test("handleAppActivated restarts when auto-start enabled")
    func handleAppActivatedRestartsWithAutoStart() {
        let settings = MockUserSettings()
        settings.autoStartTraining = true
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy(), userSettings: settings)

        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        coordinator.handleAppDeactivated()
        #expect(coordinator.isTrainingActive == false)

        coordinator.handleAppActivated()

        #expect(coordinator.isTrainingActive)
    }

    @Test("handleAppActivated does not restart when auto-start disabled")
    func handleAppActivatedDoesNotRestartWithoutAutoStart() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        coordinator.handleAppDeactivated()

        coordinator.handleAppActivated()

        #expect(coordinator.isTrainingActive == false)
    }

    // MARK: - Training Screen Lifecycle

    @Test("trainingScreenAppeared auto-starts on iOS")
    func trainingScreenAppearedAutoStartsIOS() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())

        // Use continuousRhythmMatching because it sets isRunning synchronously
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)

        #expect(coordinator.currentTrainingDestination == .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive)
    }

    @Test("trainingScreenAppeared does not auto-start on macOS")
    func trainingScreenAppearedDoesNotAutoStartMacOS() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())

        coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)

        #expect(coordinator.currentTrainingDestination == .timingOffsetDetection)
        #expect(coordinator.isTrainingActive == false)
    }

    @Test("trainingScreenDisappeared stops session and clears destination")
    func trainingScreenDisappearedStopsAndClears() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive)

        coordinator.trainingScreenDisappeared()

        #expect(coordinator.isTrainingActive == false)
        #expect(coordinator.currentTrainingDestination == nil)
    }

    // MARK: - Toggle Training

    @Test("toggleTraining starts when idle")
    func toggleTrainingStartsWhenIdle() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive == false)

        coordinator.toggleTraining()

        #expect(coordinator.isTrainingActive)
    }

    @Test("toggleTraining stops when active")
    func toggleTrainingStopsWhenActive() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        #expect(coordinator.isTrainingActive)

        coordinator.toggleTraining()

        #expect(coordinator.isTrainingActive == false)
    }

    // MARK: - Auto-Start Setting

    @Test("macOS: auto-start setting enables auto-start on screen appear")
    func autoStartSettingEnablesAutoStart() {
        let settings = MockUserSettings()
        settings.autoStartTraining = true
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy(), userSettings: settings)

        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)

        #expect(coordinator.isTrainingActive)
    }

    @Test("macOS: auto-start setting disabled does not auto-start")
    func autoStartSettingDisabledDoesNotAutoStart() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())

        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)

        #expect(coordinator.isTrainingActive == false)
    }

    @Test("macOS: auto-start setting enables auto-restart on foreground return")
    func autoStartSettingEnablesAutoRestart() {
        let settings = MockUserSettings()
        settings.autoStartTraining = true
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy(), userSettings: settings)

        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        // Auto-started, now simulate app switch and return
        coordinator.stopCurrentSession()

        coordinator.handleScenePhase(old: .inactive, new: .active)

        #expect(coordinator.isTrainingActive)
    }

    // MARK: - Help Sheet

    @Test("helpSheetPresented pauses — session stays paired with destination")
    func helpSheetPresentedKeepsSessionPaired() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive)

        coordinator.helpSheetPresented()

        // Pause does not clear `currentTrainingDestination`; the coordinator still
        // owns the destination so dismissing the sheet can resume in place.
        #expect(coordinator.currentTrainingDestination == .continuousRhythmMatching)
    }

    @Test("helpSheetDismissed restarts on iOS")
    func helpSheetDismissedRestartsOnIOS() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.helpSheetPresented()

        coordinator.helpSheetDismissed()

        #expect(coordinator.isTrainingActive)
    }

    @Test("helpSheetDismissed resumes on macOS when was active before")
    func helpSheetDismissedResumesOnMacOSWhenWasActive() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        #expect(coordinator.isTrainingActive)

        coordinator.helpSheetPresented()
        coordinator.helpSheetDismissed()

        #expect(coordinator.isTrainingActive)
    }

    @Test("helpSheetDismissed does not restart on macOS when was idle before")
    func helpSheetDismissedDoesNotRestartOnMacOSWhenWasIdle() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive == false)

        coordinator.helpSheetPresented()
        coordinator.helpSheetDismissed()

        #expect(coordinator.isTrainingActive == false)
    }

    // MARK: - startCurrentSession Dispatch

    @Test("startCurrentSession dispatches to pitch discrimination")
    func startCurrentSessionDispatchesPitchDiscrimination() async throws {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .pitchDiscrimination(isIntervalMode: false))

        coordinator.startCurrentSession()

        // Session starts asynchronously — yield to let the training task begin
        try await Task.sleep(for: .milliseconds(50))
        #expect(coordinator.isTrainingActive)
    }

    @Test("startCurrentSession dispatches to pitch matching")
    func startCurrentSessionDispatchesPitchMatching() async throws {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .pitchMatching(isIntervalMode: false))

        coordinator.startCurrentSession()

        try await Task.sleep(for: .milliseconds(50))
        #expect(coordinator.isTrainingActive)
    }

    @Test("startCurrentSession dispatches to timing offset detection")
    func startCurrentSessionDispatchesTimingOffsetDetection() async throws {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)

        coordinator.startCurrentSession()

        try await Task.sleep(for: .milliseconds(50))
        #expect(coordinator.isTrainingActive)
    }

    @Test("startCurrentSession dispatches to continuous rhythm matching")
    func startCurrentSessionDispatchesContinuousRhythm() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)

        coordinator.startCurrentSession()

        // ContinuousRhythmMatching sets isRunning synchronously
        #expect(coordinator.isTrainingActive)
    }

    @Test("startCurrentSession is no-op without destination")
    func startCurrentSessionNoOpWithoutDestination() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())

        coordinator.startCurrentSession()

        #expect(coordinator.isTrainingActive == false)
    }

    // MARK: - Menu Navigation

    @Test("navigate with no active session pushes destination immediately")
    func navigateWithNoActiveSession() async {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())

        coordinator.navigate(to: .profile)

        // Allow the internal Task to run
        await Task.yield()

        #expect(coordinator.resolvedNavigation?.destination == .profile)
    }

    @Test("navigate with active session stops session and pushes destination after idle")
    func navigateWithActiveSession() async {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        mockSession.isIdle = false
        mockSession.onStopCalled = { mockSession.isIdle = true }
        coordinator.activeSession = mockSession

        coordinator.navigate(to: .profile)

        await Task.yield()

        #expect(mockSession.stopCallCount == 1)
        #expect(coordinator.resolvedNavigation?.destination == .profile)
    }

    @Test("navigate with active session uses event-driven idle confirmation")
    func navigateUsesEventDrivenIdle() async throws {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        mockSession.isIdle = false
        // stop() does NOT set isIdle — we'll set it after the bounded poll
        coordinator.activeSession = mockSession

        coordinator.navigate(to: .profile)

        try await waitUntilStopped(mockSession)

        // Session was stopped but not yet idle — destination should not be published
        #expect(mockSession.stopCallCount == 1)
        #expect(coordinator.resolvedNavigation == nil)

        // Now session becomes idle (event-driven)
        mockSession.isIdle = true

        try await waitUntilNavigationResolved(coordinator)

        #expect(coordinator.resolvedNavigation?.destination == .profile)
    }

    @Test("rapid sequential navigations — only final destination is pushed")
    func rapidSequentialNavigations() async {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())

        coordinator.navigate(to: .pitchDiscrimination(isIntervalMode: false))
        coordinator.navigate(to: .pitchMatching(isIntervalMode: true))
        coordinator.navigate(to: .profile)

        await Task.yield()

        #expect(coordinator.resolvedNavigation?.destination == .profile)
    }

    @Test("cancellation of in-flight navigation does not leave stale state")
    func cancellationDoesNotLeaveStaleState() async {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        mockSession.isIdle = false
        coordinator.activeSession = mockSession

        // First navigation — will block waiting for idle
        coordinator.navigate(to: .pitchDiscrimination(isIntervalMode: false))
        await Task.yield()

        // Second navigation cancels the first
        mockSession.onStopCalled = { mockSession.isIdle = true }
        coordinator.navigate(to: .profile)
        await Task.yield()

        // Only the second destination should appear
        #expect(coordinator.resolvedNavigation?.destination == .profile)
    }

    // MARK: - awaitIdle Defensive Re-Check (PF-047)

    /// PF-047 contract — short-circuit path only.
    ///
    /// **What this pins.** When `session.isIdle` flips to `true` synchronously
    /// inside `stop()`, the outer `while !session.isIdle` check in `awaitIdle`
    /// short-circuits and the `withObservationTracking` body is never entered.
    /// This test pins that synchronous-flip path so the navigation resolves
    /// rather than suspending.
    ///
    /// **What this does NOT exercise.** Under default-MainActor isolation with
    /// the current synchronous `TrainingSession.isIdle`, the defensive in-block
    /// re-check inside the `withObservationTracking` body is unreachable from a
    /// test like this — the outer while-check beats it to the punch. The
    /// in-block re-check is future-proofing for any future async-`isIdle`
    /// migration where a flip could land after the outer check but before the
    /// observer installs. See the audit Risks §3 in
    /// `docs/implementation-artifacts/85-3-audit-and-harden-sequencer-concurrency.md`
    /// — the catalog's described race is "structurally impossible while
    /// `isIdle` remains a synchronous MainActor-readable property", so a
    /// pure-unit test of the in-block re-check would need an async-`isIdle`
    /// stub that the protocol cannot today express.
    @Test("navigate returns immediately when session.isIdle flips synchronously inside stop() (outer short-circuit path)")
    func awaitIdleHandlesSynchronousIdleFlip() async throws {
        // Stub session whose stop() flips `isIdle` to `true` synchronously.
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        let session = MockTrainingSession()
        session.isIdle = false
        session.onStopCalled = {
            // Synchronous flip — same MainActor turn as the navigate path's
            // stop() call. The outer `while !session.isIdle` short-circuits
            // before `withObservationTracking` is even entered.
            session.isIdle = true
        }
        coordinator.activeSession = session

        coordinator.navigate(to: .profile)

        try await waitUntilNavigationResolved(coordinator, timeout: .seconds(2))
        #expect(session.stopCallCount == 1)
        #expect(coordinator.resolvedNavigation?.destination == .profile)
    }

    // MARK: - Cross-Discipline Serialization Contract (PF-011)

    /// Contract: the previous session's sequencer stop completes BEFORE the next
    /// session's `beatSequencer.start(...)` is invoked on a CRM → TOD handover
    /// (the surface PF-011 identified). Asserted via the shared `MockBeatSequencer`'s
    /// interleaved call log: the sequence must contain `start(CRM)` … `stop` …
    /// `start(TOD)` with no overlap.
    @Test("CRM → TOD handover serializes: CRM sequencer stop completes before TOD sequencer start")
    func crmToTodHandoverSerializesSequencerStartStop() async throws {
        let fixture = makeSharedSequencerFixture()

        // Start CRM via the normal lifecycle path.
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        // Wait for CRM's startTask to actually call `beatSequencer.start`.
        try await waitUntilStartLogged(fixture.sequencer, providerType: "ContinuousRhythmMatchingSession")
        fixture.coordinator.activeSession = fixture.crm

        // Trigger the handover.
        fixture.coordinator.navigate(to: .timingOffsetDetection)
        try await waitUntilNavigationResolved(fixture.coordinator)

        // Drive TOD's start (in production, the destination resolution leads to
        // the new training screen mounting and auto-starting TOD).
        fixture.coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)
        try await waitUntilStartLogged(fixture.sequencer, providerType: "TimingOffsetDetectionSession")

        // Verify the STRUCTURAL exclusivity invariant by walking the call log
        // as a state machine: at most one provider may be "active" at a time
        // (active = its `start` has been logged but no subsequent `stop` has
        // landed yet). A `start(Y)` while X is active violates "no overlapping
        // starts"; a `start(X)` while X is already active is also a violation.
        // This is strictly stronger than `firstIndex`-based ordering — it
        // tolerates legitimate repeated starts after intervening stops (e.g.,
        // pause/resume cycles) while still catching any overlap.
        let log = fixture.sequencer.callLog
        var activeProvider: String?
        for (index, event) in log.enumerated() {
            switch event {
            case .start(let providerTypeName):
                if let existing = activeProvider {
                    Issue.record(
                        "Overlapping start at log index \(index): \(providerTypeName) started while \(existing) was still active. Full log: \(log)"
                    )
                }
                activeProvider = providerTypeName
            case .stop:
                activeProvider = nil
            }
        }

        // Sanity: both starts are present and the CRM→TOD ordering is reflected.
        let crmStartCount = log.filter {
            if case .start("ContinuousRhythmMatchingSession") = $0 { return true } else { return false }
        }.count
        let todStartCount = log.filter {
            if case .start("TimingOffsetDetectionSession") = $0 { return true } else { return false }
        }.count
        #expect(crmStartCount >= 1, "CRM start must have been logged")
        #expect(todStartCount >= 1, "TOD start must have been logged")
    }

    // MARK: - Pause / Resume Routing (PF-003, help-sheet cluster)

    @Test("trainingScreenDisappeared pauses (not stops) when session is non-idle")
    func trainingScreenDisappearedPausesSession() {
        let fixture = makeMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.mock.isIdle = false

        fixture.coordinator.trainingScreenDisappeared()

        #expect(fixture.mock.pauseCallCount == 1)
        #expect(fixture.mock.stopCallCount == 0)
        #expect(fixture.coordinator.currentTrainingDestination == nil)
    }

    @Test("trainingScreenDisappeared with idle session clears destination without pausing")
    func trainingScreenDisappearedNoOpWhenIdle() {
        let fixture = makeMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.mock.isIdle = true

        fixture.coordinator.trainingScreenDisappeared()

        #expect(fixture.mock.pauseCallCount == 0)
        #expect(fixture.mock.stopCallCount == 0)
        #expect(fixture.coordinator.currentTrainingDestination == nil)
    }

    @Test("trainingScreenAppeared with same paused destination resumes")
    func trainingScreenAppearedResumesPausedSameDestination() {
        let fixture = makeMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.mock.isIdle = false
        fixture.coordinator.trainingScreenDisappeared()
        #expect(fixture.mock.pauseCallCount == 1)

        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)

        #expect(fixture.mock.resumeCallCount == 1)
        #expect(fixture.mock.stopCallCount == 0)
    }

    @Test("trainingScreenAppeared with different destination discards stale paused session")
    func trainingScreenAppearedDiscardsPausedFromOtherDestination() {
        let fixture = makeTwoMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.crm.isIdle = false
        fixture.coordinator.trainingScreenDisappeared()
        #expect(fixture.crm.pauseCallCount == 1)

        fixture.coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)

        #expect(fixture.crm.stopCallCount == 1, "stale paused session should be terminated")
        #expect(fixture.crm.resumeCallCount == 0)
        #expect(fixture.tod.pauseCallCount == 0)
    }

    @Test("changing the TOD pattern while paused restarts playback with the new pattern on return (the reported bug)")
    func todPatternChangeWhilePausedRestartsWithNewPattern() async throws {
        // Default selectedPattern is straight16ths_01 (`* * * *`).
        let todUserSettings = MockTimingOffsetDetectionUserSettings()
        let fixture = makeFixture(policy: IOSBackgroundPolicy(), todUserSettings: todUserSettings)

        // Enter TOD — iOS auto-starts the session.
        fixture.coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)
        try await waitUntilNotIdle(fixture.todSession)

        // Leave directly to Settings — the screen disappears and the session pauses.
        fixture.coordinator.trainingScreenDisappeared()
        #expect(fixture.todSession.isIdle == false, "paused session must stay non-idle")

        // The user picks a different pattern in Settings.
        todUserSettings.selectedPattern = .pattern_gapped16ths_01

        // Return to TOD — the coordinator resumes, sees the changed snapshot, and restarts.
        fixture.coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)
        try await waitUntilNotIdle(fixture.todSession)

        // Playback now reflects the new gapped pattern (`* - * *`): subdivision 1 is a rest.
        let beat = fixture.todSession.nextBeat()
        guard case .rest = beat.subdivisions[1] else {
            Issue.record("Returning after a pattern change must play the new pattern; got \(beat.subdivisions)")
            return
        }
        fixture.todSession.stop()
    }

    @Test("returning to TOD without changing settings resumes the same trial (no new trial generated)")
    func todReturnWithoutChangeResumesSameTrial() async throws {
        // The strategy's call count is the signal that distinguishes resume (no
        // new trial) from restart (one new trial) — a scalar like
        // `currentOffsetPercentage` cannot, since the mock returns a fixed trial.
        let f = makeTodCoordinatorFixture()

        f.coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)
        try await waitUntilNotIdle(f.session)
        let trialsAfterStart = f.strategy.nextTimingOffsetDetectionTrialCallCount

        f.coordinator.trainingScreenDisappeared()
        // No settings change.
        f.coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)
        try await waitUntilNotIdle(f.session)

        #expect(
            f.strategy.nextTimingOffsetDetectionTrialCallCount == trialsAfterStart,
            "an unchanged excursion must resume the existing trial, not generate a new one"
        )
        f.session.stop()
    }

    // MARK: - reconcileForegroundSession (macOS Settings-window dismissal)

    @Test("reconcileForegroundSession restarts the foreground TOD session with the new pattern after a settings change")
    func reconcileForegroundSessionRestartsWithNewPattern() async throws {
        let f = makeTodCoordinatorFixture()
        // Training screen foreground and auto-started: currentTrainingDestination == TOD.
        f.coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)
        try await waitUntilNotIdle(f.session)
        let trialsBefore = f.strategy.nextTimingOffsetDetectionTrialCallCount

        // The user edited the pattern in the (macOS) Settings window; reconcile
        // fires when that window is dismissed.
        f.todUserSettings.selectedPattern = .pattern_gapped16ths_01
        f.coordinator.reconcileForegroundSession()

        try await waitUntilNotIdle(f.session)
        #expect(
            f.strategy.nextTimingOffsetDetectionTrialCallCount == trialsBefore + 1,
            "a changed snapshot must restart with a fresh trial"
        )
        let beat = f.session.nextBeat()
        guard case .rest = beat.subdivisions[1] else {
            Issue.record("Expected the new gapped pattern after reconcile; got \(beat.subdivisions)")
            return
        }
        f.session.stop()
    }

    @Test("reconcileForegroundSession keeps the foreground TOD session playing when nothing changed")
    func reconcileForegroundSessionUnchangedKeepsPlaying() async throws {
        let f = makeTodCoordinatorFixture()
        f.coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)
        try await waitUntilNotIdle(f.session)
        let trialsBefore = f.strategy.nextTimingOffsetDetectionTrialCallCount

        // Settings window dismissed without changing anything.
        f.coordinator.reconcileForegroundSession()

        #expect(
            f.strategy.nextTimingOffsetDetectionTrialCallCount == trialsBefore,
            "an unchanged reconcile must not restart the active session"
        )
        f.session.stop()
    }

    @Test("reconcileForegroundSession is a no-op when no training is foreground")
    func reconcileForegroundSessionNoOpWhenNoForeground() async throws {
        let f = makeTodCoordinatorFixture()
        f.coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)
        try await waitUntilNotIdle(f.session)
        // Settings opened from Start (or no training active): destination cleared.
        f.coordinator.trainingScreenDisappeared()
        let trialsBefore = f.strategy.nextTimingOffsetDetectionTrialCallCount

        f.todUserSettings.selectedPattern = .pattern_gapped16ths_01
        f.coordinator.reconcileForegroundSession()

        #expect(
            f.strategy.nextTimingOffsetDetectionTrialCallCount == trialsBefore,
            "with no foreground training, reconcile must not restart anything"
        )
        f.session.stop()
    }

    @Test("reconcileForegroundSession reconciles only the foreground discipline")
    func reconcileForegroundSessionReconcilesOnlyForeground() {
        let fixture = makeTwoMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.crm.isIdle = false

        fixture.coordinator.reconcileForegroundSession()

        #expect(fixture.crm.resumeCallCount == 1, "the foreground (CRM) session is reconciled")
        #expect(fixture.tod.resumeCallCount == 0, "a non-foreground discipline is left untouched")
    }

    @Test("helpSheetPresented pauses (not stops) the active session")
    func helpSheetPresentedPausesSession() {
        let fixture = makeMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.mock.isIdle = false

        fixture.coordinator.helpSheetPresented()

        #expect(fixture.mock.pauseCallCount == 1)
        #expect(fixture.mock.stopCallCount == 0)
    }

    @Test("helpSheetPresented on idle session is a no-op")
    func helpSheetPresentedNoOpWhenIdle() {
        let fixture = makeMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.mock.isIdle = true

        fixture.coordinator.helpSheetPresented()

        #expect(fixture.mock.pauseCallCount == 0)
        #expect(fixture.mock.stopCallCount == 0)
    }

    @Test("helpSheetDismissed resumes the paused session")
    func helpSheetDismissedResumesSession() {
        let fixture = makeMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.mock.isIdle = false
        fixture.coordinator.helpSheetPresented()

        fixture.coordinator.helpSheetDismissed()

        #expect(fixture.mock.resumeCallCount == 1)
    }

    @Test("startCurrentSession discards lingering paused session")
    func startCurrentSessionDiscardsPaused() {
        let fixture = makeMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.mock.isIdle = false
        fixture.coordinator.helpSheetPresented()
        #expect(fixture.mock.pauseCallCount == 1)

        fixture.coordinator.startCurrentSession()

        #expect(fixture.mock.stopCallCount == 1, "paused session should be stopped before fresh start")
    }

    @Test("stopCurrentSession also clears paused session")
    func stopCurrentSessionClearsPaused() {
        let fixture = makeMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.mock.isIdle = false
        fixture.coordinator.helpSheetPresented()

        fixture.coordinator.stopCurrentSession()

        // Lingering paused stopped once; current session stopped once.
        // Since they're the same mock, total stop count is 2.
        #expect(fixture.mock.stopCallCount == 2)
    }

    @Test("startScreenAppeared discards any lingering paused session (PF-003 negative case)")
    func startScreenAppearedDiscardsPaused() {
        let fixture = makeMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.mock.isIdle = false
        fixture.coordinator.trainingScreenDisappeared()
        #expect(fixture.mock.pauseCallCount == 1)

        fixture.coordinator.startScreenAppeared()

        #expect(fixture.mock.stopCallCount == 1, "pop-to-Start must terminate the paused session")
    }

    @Test("navigate clears paused session before resolving")
    func navigateClearsPaused() async {
        let fixture = makeMockFixture()
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.mock.isIdle = false
        fixture.coordinator.helpSheetPresented()
        fixture.mock.onStopCalled = { fixture.mock.isIdle = true }

        fixture.coordinator.navigate(to: .profile)

        await Task.yield()

        // The lingering paused session gets stopped before navigate proceeds.
        #expect(fixture.mock.stopCallCount >= 1)
        #expect(fixture.coordinator.resolvedNavigation?.destination == .profile)
    }

    // MARK: - Registry-Keyed Dispatch (per-destination coverage)

    @Test("registry dispatches start to every shipping training destination, leaving siblings idle", arguments: [
        NavigationDestination.pitchDiscrimination(isIntervalMode: false),
        NavigationDestination.pitchDiscrimination(isIntervalMode: true),
        NavigationDestination.pitchMatching(isIntervalMode: false),
        NavigationDestination.pitchMatching(isIntervalMode: true),
        NavigationDestination.timingOffsetDetection,
        NavigationDestination.continuousRhythmMatching,
    ])
    func registryDispatchesEveryTrainingDestination(destination: NavigationDestination) async throws {
        let fixture = makeFixture(policy: MacOSBackgroundPolicy())
        let expected: any TrainingSession = switch destination {
        case .pitchDiscrimination: fixture.pdSession
        case .pitchMatching: fixture.pmSession
        case .timingOffsetDetection: fixture.todSession
        case .continuousRhythmMatching: fixture.crmSession
        case .settings, .profile: fatalError("non-training destination not in test arguments")
        case .chromaticConstruction: fatalError("chromatic-construction destination not in test arguments")
        }

        fixture.coordinator.trainingScreenAppeared(destination: destination)
        fixture.coordinator.startCurrentSession()

        try await waitUntilNotIdle(expected)

        for session in fixture.allSessions {
            if session === expected {
                #expect(session.isIdle == false, "expected session for \(destination) to start")
            } else {
                #expect(session.isIdle, "sibling session became active for \(destination)")
            }
        }
    }

    // MARK: - Audio Infrastructure Lifecycle (Story 85.8)

    @Test("handleAudioStopRequired stops current session")
    func handleAudioStopRequiredRoutesThroughStopCurrentSession() async throws {
        let fixture = makeFixture(policy: IOSBackgroundPolicy())
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.coordinator.startCurrentSession()
        try await waitUntilNotIdle(fixture.crmSession)

        fixture.coordinator.handleAudioStopRequired()

        #expect(fixture.coordinator.isTrainingActive == false)
    }

    @Test("handleMediaServicesLost sets mediaRebuildPending")
    func handleMediaServicesLostSetsPendingFlag() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        #expect(coordinator.mediaRebuildPending == false)

        coordinator.handleMediaServicesLost()

        #expect(coordinator.mediaRebuildPending == true)
    }

    @Test("handleMediaServicesLost stops current session")
    func handleMediaServicesLostStopsSession() async throws {
        let fixture = makeFixture(policy: IOSBackgroundPolicy())
        fixture.coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        fixture.coordinator.startCurrentSession()
        try await waitUntilNotIdle(fixture.crmSession)

        fixture.coordinator.handleMediaServicesLost()

        // Session Tasks reference now-dead samplers; coordinator must stop
        // the session synchronously rather than wait for Reset.
        #expect(fixture.coordinator.isTrainingActive == false)
    }

    @Test("handleMediaServicesReset stops session and invokes rebuild closure")
    func handleMediaServicesResetStopsAndRebuilds() async throws {
        var rebuildCallCount = 0
        let policy = IOSBackgroundPolicy()
        let fixture = makeFixture(policy: policy)
        // Replace the coordinator with one that uses a spy rebuild closure;
        // sessions stay attached to the fixture's registry.
        let registry = TrainingLifecycleRegistry { builder in
            fixture.pdSession.contribute(to: builder, userSettings: MockUserSettings())
            fixture.pmSession.contribute(to: builder, userSettings: MockUserSettings())
            fixture.todSession.contribute(to: builder, userSettings: MockUserSettings(), todUserSettings: MockTimingOffsetDetectionUserSettings())
            fixture.crmSession.contribute(to: builder, userSettings: MockUserSettings(), crmUserSettings: MockContinuousRhythmMatchingUserSettings())
        }
        let coordinator = TrainingLifecycleCoordinator(
            registry: registry,
            backgroundPolicy: policy,
            initialAutoStartSetting: true,
            mediaInfrastructureRebuild: {
                rebuildCallCount += 1
            }
        )
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        try await waitUntilNotIdle(fixture.crmSession)

        coordinator.handleMediaServicesReset()

        // The rebuild closure runs in a Task; wait for it to complete.
        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()

        #expect(coordinator.isTrainingActive == false)
        #expect(rebuildCallCount == 1)
        #expect(coordinator.mediaRebuildPending == false)
    }

    @Test("Lost-then-Reset clears mediaRebuildPending after rebuild")
    func lostThenResetClearsPendingFlag() async throws {
        let policy = IOSBackgroundPolicy()
        let fixture = makeFixture(policy: policy)
        let registry = TrainingLifecycleRegistry { builder in
            fixture.pdSession.contribute(to: builder, userSettings: MockUserSettings())
            fixture.pmSession.contribute(to: builder, userSettings: MockUserSettings())
            fixture.todSession.contribute(to: builder, userSettings: MockUserSettings(), todUserSettings: MockTimingOffsetDetectionUserSettings())
            fixture.crmSession.contribute(to: builder, userSettings: MockUserSettings(), crmUserSettings: MockContinuousRhythmMatchingUserSettings())
        }
        let coordinator = TrainingLifecycleCoordinator(
            registry: registry,
            backgroundPolicy: policy,
            initialAutoStartSetting: true,
            mediaInfrastructureRebuild: { }
        )

        coordinator.handleMediaServicesLost()
        #expect(coordinator.mediaRebuildPending == true)

        coordinator.handleMediaServicesReset()
        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()

        #expect(coordinator.mediaRebuildPending == false)
    }

    // MARK: - Helpers

    private struct LifecycleFixture {
        let coordinator: TrainingLifecycleCoordinator
        let pdSession: PitchDiscriminationSession
        let pmSession: PitchMatchingSession
        let todSession: TimingOffsetDetectionSession
        let crmSession: ContinuousRhythmMatchingSession

        var allSessions: [any TrainingSession] {
            [pdSession, pmSession, todSession, crmSession]
        }
    }

    private func makeFixture(
        policy: BackgroundPolicy,
        userSettings: MockUserSettings = MockUserSettings(),
        crmUserSettings: MockContinuousRhythmMatchingUserSettings = MockContinuousRhythmMatchingUserSettings(),
        todUserSettings: MockTimingOffsetDetectionUserSettings = MockTimingOffsetDetectionUserSettings()
    ) -> LifecycleFixture {
        let notePlayer = MockNotePlayer()
        notePlayer.instantPlayback = true
        let profile = PerceptualProfile()
        let pdSession = PitchDiscriminationSession(
            notePlayer: notePlayer,
            strategy: MockNextPitchDiscriminationStrategy(),
            profile: profile,
            observers: []
        )
        let pmSession = PitchMatchingSession(
            notePlayer: notePlayer,
            profile: profile
        )
        let todSession = TimingOffsetDetectionSession(
            beatSequencer: MockBeatSequencer(),
            strategy: MockNextTimingOffsetDetectionStrategy(),
            profile: profile
        )
        let crmSession = ContinuousRhythmMatchingSession(
            beatSequencer: MockBeatSequencer()
        )
        let registry = TrainingLifecycleRegistry { builder in
            pdSession.contribute(to: builder, userSettings: userSettings)
            pmSession.contribute(to: builder, userSettings: userSettings)
            todSession.contribute(to: builder, userSettings: userSettings, todUserSettings: todUserSettings)
            crmSession.contribute(to: builder, userSettings: userSettings, crmUserSettings: crmUserSettings)
        }
        let coordinator = TrainingLifecycleCoordinator(
            registry: registry,
            backgroundPolicy: policy,
            initialAutoStartSetting: userSettings.autoStartTraining,
            mediaInfrastructureRebuild: { }
        )
        return LifecycleFixture(
            coordinator: coordinator,
            pdSession: pdSession,
            pmSession: pmSession,
            todSession: todSession,
            crmSession: crmSession
        )
    }

    private func makeCoordinator(
        policy: BackgroundPolicy,
        userSettings: MockUserSettings = MockUserSettings(),
        crmUserSettings: MockContinuousRhythmMatchingUserSettings = MockContinuousRhythmMatchingUserSettings(),
        todUserSettings: MockTimingOffsetDetectionUserSettings = MockTimingOffsetDetectionUserSettings()
    ) -> TrainingLifecycleCoordinator {
        makeFixture(
            policy: policy,
            userSettings: userSettings,
            crmUserSettings: crmUserSettings,
            todUserSettings: todUserSettings
        ).coordinator
    }

    // MARK: - Real-TOD Coordinator Fixture (settings-aware reconcile tests)

    private struct TodCoordinatorFixture {
        let coordinator: TrainingLifecycleCoordinator
        let session: TimingOffsetDetectionSession
        let strategy: MockNextTimingOffsetDetectionStrategy
        let todUserSettings: MockTimingOffsetDetectionUserSettings
    }

    private func makeTodCoordinatorFixture(
        policy: BackgroundPolicy = IOSBackgroundPolicy()
    ) -> TodCoordinatorFixture {
        let strategy = MockNextTimingOffsetDetectionStrategy()
        let todUserSettings = MockTimingOffsetDetectionUserSettings()
        let session = TimingOffsetDetectionSession(
            beatSequencer: MockBeatSequencer(),
            strategy: strategy,
            profile: PerceptualProfile()
        )
        let registry = TrainingLifecycleRegistry { builder in
            session.contribute(to: builder, userSettings: MockUserSettings(), todUserSettings: todUserSettings)
        }
        let coordinator = TrainingLifecycleCoordinator(
            registry: registry,
            backgroundPolicy: policy,
            initialAutoStartSetting: true,
            mediaInfrastructureRebuild: { }
        )
        return TodCoordinatorFixture(
            coordinator: coordinator,
            session: session,
            strategy: strategy,
            todUserSettings: todUserSettings
        )
    }

    // MARK: - Mock Fixtures (pause/resume routing tests)

    private struct MockFixture {
        let coordinator: TrainingLifecycleCoordinator
        let mock: MockTrainingSession
    }

    /// Cross-discipline serialization test fixture: real TOD + CRM sessions
    /// backed by a SHARED `MockBeatSequencer`, mirroring the production wiring
    /// where both disciplines share one `SoundFontBeatSequencer` instance.
    private struct SharedSequencerFixture {
        let coordinator: TrainingLifecycleCoordinator
        let crm: ContinuousRhythmMatchingSession
        let tod: TimingOffsetDetectionSession
        let sequencer: MockBeatSequencer
    }

    private func makeSharedSequencerFixture() -> SharedSequencerFixture {
        let sequencer = MockBeatSequencer()
        sequencer.samplesPerBeat = 22050
        sequencer.sampleRate = .standard44100

        let profile = PerceptualProfile()
        let userSettings = MockUserSettings()
        let crmUserSettings = MockContinuousRhythmMatchingUserSettings()
        let todUserSettings = MockTimingOffsetDetectionUserSettings()

        let crm = ContinuousRhythmMatchingSession(
            beatSequencer: sequencer
        )
        let tod = TimingOffsetDetectionSession(
            beatSequencer: sequencer,
            strategy: MockNextTimingOffsetDetectionStrategy(),
            profile: profile
        )

        let registry = TrainingLifecycleRegistry { builder in
            crm.contribute(to: builder, userSettings: userSettings, crmUserSettings: crmUserSettings)
            tod.contribute(to: builder, userSettings: userSettings, todUserSettings: todUserSettings)
        }
        // Mirror `PeachApp.makeBackgroundPolicy()` so the fixture exercises the
        // same lifecycle policy the production composition root selects on the
        // test platform. macOS runs (`bin/test.sh -p mac`) previously hardcoded
        // an iOS policy, masking macOS-specific lifecycle behaviour.
        #if os(iOS)
        let backgroundPolicy: BackgroundPolicy = IOSBackgroundPolicy()
        #elseif os(macOS)
        let backgroundPolicy: BackgroundPolicy = MacOSBackgroundPolicy()
        #else
        #error("Unsupported platform")
        #endif
        let coordinator = TrainingLifecycleCoordinator(
            registry: registry,
            backgroundPolicy: backgroundPolicy,
            initialAutoStartSetting: true,
            mediaInfrastructureRebuild: { }
        )
        return SharedSequencerFixture(coordinator: coordinator, crm: crm, tod: tod, sequencer: sequencer)
    }

    private func waitUntilStartLogged(
        _ sequencer: MockBeatSequencer,
        providerType: String,
        timeout: Duration = .seconds(1)
    ) async throws {
        let target: MockBeatSequencer.CallEvent = .start(providerTypeName: providerType)
        let deadline = ContinuousClock.now + timeout
        while !sequencer.callLog.contains(target) {
            if ContinuousClock.now >= deadline {
                Issue.record("sequencer did not log \(target) within \(timeout); log = \(sequencer.callLog)")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private struct TwoMockFixture {
        let coordinator: TrainingLifecycleCoordinator
        let crm: MockTrainingSession
        let tod: MockTrainingSession
    }

    private func makeMockFixture() -> MockFixture {
        let mock = MockTrainingSession()
        let registry = TrainingLifecycleRegistry { builder in
            builder.register(
                destination: .continuousRhythmMatching,
                session: mock,
                start: { mock.isIdle = false },
                reconcile: { mock.resume() }
            )
        }
        let coordinator = TrainingLifecycleCoordinator(
            registry: registry,
            backgroundPolicy: IOSBackgroundPolicy(),
            initialAutoStartSetting: true,
            mediaInfrastructureRebuild: { }
        )
        return MockFixture(coordinator: coordinator, mock: mock)
    }

    private func makeTwoMockFixture() -> TwoMockFixture {
        let crm = MockTrainingSession()
        let tod = MockTrainingSession()
        let registry = TrainingLifecycleRegistry { builder in
            builder.register(
                destination: .continuousRhythmMatching,
                session: crm,
                start: { crm.isIdle = false },
                reconcile: { crm.resume() }
            )
            builder.register(
                destination: .timingOffsetDetection,
                session: tod,
                start: { tod.isIdle = false },
                reconcile: { tod.resume() }
            )
        }
        let coordinator = TrainingLifecycleCoordinator(
            registry: registry,
            backgroundPolicy: IOSBackgroundPolicy(),
            initialAutoStartSetting: true,
            mediaInfrastructureRebuild: { }
        )
        return TwoMockFixture(coordinator: coordinator, crm: crm, tod: tod)
    }

    private func waitUntilNotIdle(_ session: any TrainingSession, timeout: Duration = .seconds(1)) async throws {
        let deadline = ContinuousClock.now + timeout
        while session.isIdle {
            if ContinuousClock.now >= deadline {
                Issue.record("session did not become active within \(timeout)")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func waitUntilStopped(_ session: MockTrainingSession, timeout: Duration = .seconds(1)) async throws {
        let deadline = ContinuousClock.now + timeout
        while session.stopCallCount == 0 {
            if ContinuousClock.now >= deadline {
                Issue.record("session.stop() was not called within \(timeout)")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func waitUntilNavigationResolved(_ coordinator: TrainingLifecycleCoordinator, timeout: Duration = .seconds(1)) async throws {
        let deadline = ContinuousClock.now + timeout
        while coordinator.resolvedNavigation == nil {
            if ContinuousClock.now >= deadline {
                Issue.record("coordinator did not resolve navigation within \(timeout)")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

@Observable
private final class MockTrainingSession: TrainingSession {
    var isIdle: Bool = true
    var stopCallCount = 0
    var pauseCallCount = 0
    var resumeCallCount = 0
    var onStopCalled: (() -> Void)?

    func stop() {
        stopCallCount += 1
        onStopCalled?()
    }

    func pause() {
        pauseCallCount += 1
    }

    func resume() {
        resumeCallCount += 1
    }
}
