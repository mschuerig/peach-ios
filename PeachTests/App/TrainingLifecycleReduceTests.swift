import Testing
@testable import Peach

/// Pure state-machine coverage for `TrainingLifecycleCoordinator.reduce`. Mirrors
/// `PitchDiscriminationReduceTests`: every event is exercised from the reachable
/// states, asserting the resulting `State` and `[Effect]`. The behavioural suite
/// (`TrainingLifecycleCoordinatorTests`) covers the effect *interpretation*; this
/// suite pins the *decisions* — including the PF-049/050/079 interleavings.
@Suite("TrainingLifecycleReduce")
struct TrainingLifecycleReduceTests {
    typealias State = TrainingLifecycleCoordinator.State
    typealias Event = TrainingLifecycleCoordinator.Event
    typealias Effect = TrainingLifecycleCoordinator.Effect
    typealias Context = TrainingLifecycleCoordinator.Context
    typealias Reason = TrainingLifecycleCoordinator.ForegroundSuspensionReason

    // Two associated-value-free training destinations + a menu target.
    let d1 = NavigationDestination.timingOffsetDetection
    let d2 = NavigationDestination.continuousRhythmMatching
    let menu = NavigationDestination.profile

    private func makeState(
        policyAutoStart: Bool = true,
        current: NavigationDestination? = nil,
        paused: NavigationDestination? = nil,
        suspensions: Set<Reason> = [],
        autoStartSetting: Bool = false,
        mediaRebuildPending: Bool = false
    ) -> State {
        var s = State(policyAutoStart: policyAutoStart, autoStartSetting: autoStartSetting)
        s.currentTrainingDestination = current
        s.pausedDestination = paused
        s.foregroundSuspensions = suspensions
        s.mediaRebuildPending = mediaRebuildPending
        return s
    }

    @discardableResult
    private func reduce(_ state: inout State, _ event: Event, idle: Bool) -> [Effect] {
        TrainingLifecycleCoordinator.reduce(
            state: &state, event: event, context: Context(foregroundSessionIsIdle: idle)
        )
    }

    // MARK: - Scene Phase

    @Test("background that should stop → stops current and clears lingering pause")
    func scenePhaseBackgroundStops() {
        var s = makeState(current: d1, paused: d1, suspensions: [.helpWindow])
        let effects = reduce(&s, .scenePhaseChanged(.background, shouldStop: true), idle: false)
        #expect(effects == [.stopSession(d1), .stopSession(d1)])
        #expect(s.pausedDestination == nil)
        #expect(s.currentTrainingDestination == d1, "destination survives a stop")
        #expect(s.foregroundSuspensions == [.helpWindow], "suspension survives backgrounding")
    }

    @Test("return to active auto-restarts an idle foreground session")
    func scenePhaseActiveRestarts() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .scenePhaseChanged(.active, shouldStop: false), idle: true)
        #expect(effects == [.startSession(d1)])
    }

    @Test("PF-079: return to active does NOT restart while suspended (both platforms)")
    func scenePhaseActiveSuppressedWhileSuspended() {
        var s = makeState(current: d1, suspensions: [.helpWindow])
        let effects = reduce(&s, .scenePhaseChanged(.active, shouldStop: false), idle: true)
        #expect(effects.isEmpty, "no audio behind the Help sheet on iOS")
    }

    @Test("return to active is a no-op when training is already running")
    func scenePhaseActiveNoOpWhenActive() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .scenePhaseChanged(.active, shouldStop: false), idle: false)
        #expect(effects.isEmpty)
    }

    @Test("return to active is a no-op without a destination")
    func scenePhaseActiveNoOpWithoutDestination() {
        var s = makeState(current: nil)
        let effects = reduce(&s, .scenePhaseChanged(.active, shouldStop: false), idle: true)
        #expect(effects.isEmpty)
    }

    @Test("return to active does not restart when auto-start is off (macOS)")
    func scenePhaseActiveNoOpWhenAutoStartOff() {
        var s = makeState(policyAutoStart: false, current: d1, autoStartSetting: false)
        let effects = reduce(&s, .scenePhaseChanged(.active, shouldStop: false), idle: true)
        #expect(effects.isEmpty)
    }

    // MARK: - App Activation (macOS)

    @Test("appActivated restarts an idle foreground session when policy allows")
    func appActivatedRestarts() {
        var s = makeState(policyAutoStart: false, current: d1, autoStartSetting: true)
        let effects = reduce(&s, .appActivated, idle: true)
        #expect(effects == [.startSession(d1)])
    }

    @Test("appActivated is suppressed while suspended")
    func appActivatedSuppressedWhileSuspended() {
        var s = makeState(policyAutoStart: false, current: d1, suspensions: [.settingsWindow], autoStartSetting: true)
        let effects = reduce(&s, .appActivated, idle: true)
        #expect(effects.isEmpty)
    }

    @Test("appDeactivated stops the current session")
    func appDeactivatedStops() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .appDeactivated, idle: false)
        #expect(effects == [.stopSession(d1)])
    }

    // MARK: - Training Screen Lifecycle

    @Test("appear on the paused destination reconciles and clears the pause")
    func appearResumesPausedDestination() {
        var s = makeState(current: nil, paused: d1)
        let effects = reduce(&s, .trainingScreenAppeared(d1), idle: false)
        #expect(effects == [.reconcileSession(d1)])
        #expect(s.currentTrainingDestination == d1)
        #expect(s.pausedDestination == nil)
    }

    @Test("appear on a fresh destination auto-starts and discards a stale pause")
    func appearStartsFreshDestination() {
        var s = makeState(current: nil, paused: d2)
        let effects = reduce(&s, .trainingScreenAppeared(d1), idle: true)
        #expect(effects == [.stopSession(d2), .startSession(d1)])
        #expect(s.currentTrainingDestination == d1)
        #expect(s.pausedDestination == nil)
    }

    @Test("appear does not auto-start behind an open auxiliary window")
    func appearSuppressedWhileSuspended() {
        var s = makeState(current: nil, suspensions: [.settingsWindow])
        let effects = reduce(&s, .trainingScreenAppeared(d1), idle: true)
        #expect(effects.isEmpty)
        #expect(s.currentTrainingDestination == d1)
    }

    @Test("disappear pauses an active foreground session")
    func disappearPausesActive() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .trainingScreenDisappeared, idle: false)
        #expect(effects == [.pauseSession(d1)])
        #expect(s.pausedDestination == d1)
        #expect(s.currentTrainingDestination == nil)
    }

    @Test("disappear on an idle session just clears the destination")
    func disappearIdleClearsDestination() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .trainingScreenDisappeared, idle: true)
        #expect(effects.isEmpty)
        #expect(s.currentTrainingDestination == nil)
        #expect(s.pausedDestination == nil)
    }

    @Test("disappear with no destination is a no-op")
    func disappearNoDestination() {
        var s = makeState(current: nil)
        let effects = reduce(&s, .trainingScreenDisappeared, idle: true)
        #expect(effects.isEmpty)
    }

    @Test("startScreenAppeared discards a lingering pause")
    func startScreenDiscardsPause() {
        var s = makeState(current: nil, paused: d1)
        let effects = reduce(&s, .startScreenAppeared, idle: true)
        #expect(effects == [.stopSession(d1)])
        #expect(s.pausedDestination == nil)
    }

    @Test("startScreenAppeared with no pause is a no-op")
    func startScreenNoPause() {
        var s = makeState(current: nil, paused: nil)
        let effects = reduce(&s, .startScreenAppeared, idle: true)
        #expect(effects.isEmpty)
    }

    // MARK: - Foreground Suspension (multi-owner)

    @Test("first suspension reason pauses an active foreground session")
    func firstSuspensionPauses() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .foregroundSuspended(.helpWindow), idle: false)
        #expect(effects == [.pauseSession(d1)])
        #expect(s.pausedDestination == d1)
        #expect(s.foregroundSuspensions == [.helpWindow])
    }

    @Test("second suspension reason does not re-pause")
    func secondSuspensionNoRepause() {
        var s = makeState(current: d1, paused: d1, suspensions: [.helpWindow])
        let effects = reduce(&s, .foregroundSuspended(.settingsWindow), idle: false)
        #expect(effects.isEmpty)
        #expect(s.foregroundSuspensions == [.helpWindow, .settingsWindow])
    }

    @Test("suspension with no foreground training records the reason only")
    func suspensionNoForegroundRecordsReason() {
        var s = makeState(current: nil)
        let effects = reduce(&s, .foregroundSuspended(.settingsWindow), idle: true)
        #expect(effects.isEmpty)
        #expect(s.foregroundSuspensions == [.settingsWindow])
        #expect(s.pausedDestination == nil)
    }

    @Test("suspension of an idle foreground session records the reason only")
    func suspensionIdleForegroundRecordsReason() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .foregroundSuspended(.settingsWindow), idle: true)
        #expect(effects.isEmpty)
        #expect(s.foregroundSuspensions == [.settingsWindow])
        #expect(s.pausedDestination == nil)
    }

    @Test("releasing the last reason reconciles a still-active session")
    func releaseLastReconciles() {
        var s = makeState(current: d1, paused: d1, suspensions: [.helpWindow])
        let effects = reduce(&s, .foregroundReleased(.helpWindow, autoStartIfIdle: true), idle: false)
        #expect(effects == [.reconcileSession(d1)])
        #expect(s.pausedDestination == nil)
        #expect(s.foregroundSuspensions.isEmpty)
    }

    @Test("releasing the last reason auto-starts a session that went idle")
    func releaseLastStartsIdle() {
        var s = makeState(current: d1, paused: d1, suspensions: [.helpWindow])
        let effects = reduce(&s, .foregroundReleased(.helpWindow, autoStartIfIdle: true), idle: true)
        #expect(effects == [.startSession(d1)])
        #expect(s.pausedDestination == nil)
    }

    @Test("releasing one of two reasons keeps the session suspended")
    func releaseNotLastNoOp() {
        var s = makeState(current: d1, paused: d1, suspensions: [.helpWindow, .settingsWindow])
        let effects = reduce(&s, .foregroundReleased(.settingsWindow, autoStartIfIdle: true), idle: false)
        #expect(effects.isEmpty)
        #expect(s.foregroundSuspensions == [.helpWindow])
        #expect(s.pausedDestination == d1, "still paused")
    }

    @Test("releasing with no foreground destination leaves a navigation pause untouched")
    func releaseNoDestinationLeavesNavigationPause() {
        var s = makeState(current: nil, paused: d2, suspensions: [.settingsWindow])
        let effects = reduce(&s, .foregroundReleased(.settingsWindow, autoStartIfIdle: true), idle: true)
        #expect(effects.isEmpty, "no current destination → startCurrent is a no-op")
        #expect(s.pausedDestination == d2, "navigation pause owns this marker")
    }

    // MARK: - Toggle / Start / Stop

    @Test("toggle stops an active session")
    func toggleStopsActive() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .toggleRequested, idle: false)
        #expect(effects == [.stopSession(d1)])
    }

    @Test("toggle starts an idle session")
    func toggleStartsIdle() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .toggleRequested, idle: true)
        #expect(effects == [.startSession(d1)])
    }

    @Test("startRequested discards a lingering pause then starts")
    func startRequestedDiscardsThenStarts() {
        var s = makeState(current: d1, paused: d2)
        let effects = reduce(&s, .startRequested, idle: true)
        #expect(effects == [.stopSession(d2), .startSession(d1)])
        #expect(s.pausedDestination == nil)
    }

    @Test("startRequested without a destination is a no-op")
    func startRequestedNoDestination() {
        var s = makeState(current: nil, paused: d2)
        let effects = reduce(&s, .startRequested, idle: true)
        #expect(effects.isEmpty)
        #expect(s.pausedDestination == d2, "no destination → no discard (guard precedes it)")
    }

    @Test("stopRequested stops current and clears any pause")
    func stopRequestedStops() {
        var s = makeState(current: d1, paused: d1)
        let effects = reduce(&s, .stopRequested, idle: false)
        #expect(effects == [.stopSession(d1), .stopSession(d1)])
        #expect(s.pausedDestination == nil)
    }

    @Test("audioStopRequired stops current")
    func audioStopRequiredStops() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .audioStopRequired, idle: false)
        #expect(effects == [.stopSession(d1)])
    }

    // MARK: - Media Services

    @Test("mediaServicesLost stops current and marks a rebuild pending")
    func mediaLostStopsAndMarks() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .mediaServicesLost, idle: false)
        #expect(effects == [.stopSession(d1)])
        #expect(s.mediaRebuildPending)
    }

    @Test("mediaServicesReset stops current and rebuilds infrastructure")
    func mediaResetStopsAndRebuilds() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .mediaServicesReset, idle: false)
        #expect(effects == [.stopSession(d1), .rebuildMediaInfrastructure])
    }

    @Test("mediaRebuildCompleted clears the pending flag")
    func mediaRebuildCompletedClears() {
        var s = makeState(mediaRebuildPending: true)
        let effects = reduce(&s, .mediaRebuildCompleted, idle: true)
        #expect(effects.isEmpty)
        #expect(s.mediaRebuildPending == false)
    }

    // MARK: - Sound Source / Navigation

    @Test("soundSourceChanged discards pause then stops all non-idle sessions")
    func soundSourceStopsAll() {
        var s = makeState(current: d1, paused: d2)
        let effects = reduce(&s, .soundSourceChanged, idle: false)
        #expect(effects == [.stopSession(d2), .stopAllNonIdleSessions])
        #expect(s.pausedDestination == nil)
        #expect(s.currentTrainingDestination == d1, "destination survives a sound-source change")
    }

    @Test("soundSourceChanged while idle emits only the stop-all sweep")
    func soundSourceIdle() {
        var s = makeState(current: d1)
        let effects = reduce(&s, .soundSourceChanged, idle: true)
        #expect(effects == [.stopAllNonIdleSessions])
    }

    @Test("navigationRequested discards pause then navigates")
    func navigationDiscardsThenNavigates() {
        var s = makeState(current: d1, paused: d1)
        let effects = reduce(&s, .navigationRequested(menu), idle: false)
        #expect(effects == [.stopSession(d1), .navigate(menu)])
        #expect(s.pausedDestination == nil)
    }

    // MARK: - PF Interleavings (explicit)

    @Test("PF-049: interruption behind the Help sheet, then dismiss → auto-start")
    func pf049InterruptionThenDismiss() {
        var s = makeState(current: d1)
        // Help opens over active training.
        reduce(&s, .foregroundSuspended(.helpWindow), idle: false)
        #expect(s.pausedDestination == d1)
        // Audio interruption stops everything; the destination survives.
        let stopEffects = reduce(&s, .audioStopRequired, idle: false)
        #expect(stopEffects == [.stopSession(d1), .stopSession(d1)])
        #expect(s.pausedDestination == nil)
        #expect(s.currentTrainingDestination == d1)
        // Dismiss → the session is idle now → auto-start (no dead screen).
        let dismissEffects = reduce(&s, .foregroundReleased(.helpWindow, autoStartIfIdle: true), idle: true)
        #expect(dismissEffects == [.startSession(d1)])
    }

    @Test("PF-050/079: background + return behind the Help sheet plays nothing until dismiss")
    func pf050BackgroundReturnThenDismiss() {
        var s = makeState(current: d1)
        reduce(&s, .foregroundSuspended(.helpWindow), idle: false)
        // Background stops (documented trial downgrade); suspension survives.
        reduce(&s, .scenePhaseChanged(.background, shouldStop: true), idle: false)
        #expect(s.foregroundSuspensions == [.helpWindow])
        #expect(s.currentTrainingDestination == d1)
        // Return active while still suspended → nothing plays behind the sheet.
        let returnEffects = reduce(&s, .scenePhaseChanged(.active, shouldStop: false), idle: true)
        #expect(returnEffects.isEmpty)
        // Dismiss → single cold start.
        let dismissEffects = reduce(&s, .foregroundReleased(.helpWindow, autoStartIfIdle: true), idle: true)
        #expect(dismissEffects == [.startSession(d1)])
    }

    @Test("Settings + Help both open, closed in either order, reconcile only at the last")
    func multiOwnerReleaseOrder() {
        var s = makeState(current: d1)
        reduce(&s, .foregroundSuspended(.settingsWindow), idle: false)   // pause
        #expect(s.pausedDestination == d1)
        reduce(&s, .foregroundSuspended(.helpWindow), idle: false)       // no re-pause
        let firstRelease = reduce(&s, .foregroundReleased(.settingsWindow, autoStartIfIdle: true), idle: false)
        #expect(firstRelease.isEmpty, "Help still owns the suspension")
        let lastRelease = reduce(&s, .foregroundReleased(.helpWindow, autoStartIfIdle: true), idle: false)
        #expect(lastRelease == [.reconcileSession(d1)])
        #expect(s.foregroundSuspensions.isEmpty)
    }

    @Test("multi-owner release is order-independent: Help released first, then Settings")
    func multiOwnerReleaseReverseOrder() {
        var s = makeState(current: d1)
        reduce(&s, .foregroundSuspended(.helpWindow), idle: false)         // pause
        reduce(&s, .foregroundSuspended(.settingsWindow), idle: false)     // no re-pause
        let firstRelease = reduce(&s, .foregroundReleased(.helpWindow, autoStartIfIdle: true), idle: false)
        #expect(firstRelease.isEmpty, "Settings still owns the suspension")
        let lastRelease = reduce(&s, .foregroundReleased(.settingsWindow, autoStartIfIdle: true), idle: false)
        #expect(lastRelease == [.reconcileSession(d1)])
        #expect(s.foregroundSuspensions.isEmpty)
    }

    @Test("duplicate mediaServicesLost is a benign no-op that keeps the rebuild pending")
    func duplicateMediaLostIsBenign() {
        var s = makeState(current: nil, mediaRebuildPending: true)
        let effects = reduce(&s, .mediaServicesLost, idle: true)
        #expect(effects.isEmpty, "nothing to stop; flag already set")
        #expect(s.mediaRebuildPending, "stays pending")
    }
}
