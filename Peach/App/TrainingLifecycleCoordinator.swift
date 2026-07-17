import Observation
import SwiftUI
import os

extension AppScenePhase {
    init(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active: self = .active
        case .inactive: self = .inactive
        case .background: self = .background
        @unknown default: self = .inactive
        }
    }
}

struct NavigationRequest: Equatable {
    let destination: NavigationDestination
    private let id = UUID()

    static func == (lhs: NavigationRequest, rhs: NavigationRequest) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
final class TrainingLifecycleCoordinator {
    private let registry: TrainingLifecycleRegistry
    private let backgroundPolicy: BackgroundPolicy

    /// Invoked when `mediaServicesWereResetNotification` fires. The production
    /// wiring forwards to `SoundFontEngine.rebuildAfterMediaReset`; tests can
    /// substitute a spy. The coordinator owns the policy ("stop active session,
    /// then rebuild infrastructure") and the closure owns the mechanism.
    private let mediaInfrastructureRebuild: () async throws -> Void

    /// Set when `mediaServicesWereLost` posted but `mediaServicesWereReset`
    /// has not yet arrived. The Reset handler observes this for diagnostics
    /// (a Reset without a prior Lost still rebuilds; the flag is permissive).
    private(set) var mediaRebuildPending: Bool = false

    var activeSession: (any TrainingSession)?

    private(set) var resolvedNavigation: NavigationRequest?
    private var navigationTask: Task<Void, Never>?

    private(set) var currentTrainingDestination: NavigationDestination?

    /// Destination whose session was paused by a navigation event (training
    /// screen disappear). Tracking the destination instead of the session
    /// instance avoids coupling to the registry's instance-identity guarantee.
    private var pausedDestination: NavigationDestination?

    /// A macOS auxiliary window that holds the foreground training session
    /// suspended while it is open. The two windows can be open at once, so
    /// suspension is multi-owner: the session pauses on the first reason and
    /// only reconciles/resumes once the *last* reason clears.
    enum ForegroundSuspensionReason {
        case settingsWindow
        case helpWindow
    }

    private var foregroundSuspensions: Set<ForegroundSuspensionReason> = []

    /// True while at least one auxiliary window (Settings or Help) suspends the
    /// foreground training session. The macOS training surface reads this to
    /// make itself non-interactive; otherwise a click (e.g. a Timing Offset
    /// Detection answer button) would resume audio behind the open window. iOS
    /// never adds the `.settingsWindow` reason (its Settings is a pushed screen),
    /// and its Help sheet already covers the surface, so this drives no iOS UI.
    var isForegroundSuspended: Bool { !foregroundSuspensions.isEmpty }

    private static let logger = Logger(subsystem: "com.peach.app", category: "Lifecycle")

    init(
        registry: TrainingLifecycleRegistry,
        backgroundPolicy: BackgroundPolicy,
        initialAutoStartSetting: Bool,
        mediaInfrastructureRebuild: @escaping () async throws -> Void
    ) {
        self.registry = registry
        self.backgroundPolicy = backgroundPolicy
        self.autoStartSetting = initialAutoStartSetting
        self.mediaInfrastructureRebuild = mediaInfrastructureRebuild
    }

    // MARK: - Computed Properties

    private var currentSession: (any TrainingSession)? {
        guard let destination = currentTrainingDestination else { return nil }
        return registry.contribution(for: destination)?.session
    }

    var isTrainingActive: Bool {
        guard let session = currentSession else { return false }
        return !session.isIdle
    }

    var shouldAutoStartTraining: Bool {
        backgroundPolicy.shouldAutoStartTraining || autoStartSetting
    }

    /// User preference for auto-starting training (macOS only, persisted via UserDefaults).
    /// On iOS, `backgroundPolicy.shouldAutoStartTraining` is always true, so this has no effect.
    var autoStartSetting: Bool

    // MARK: - Scene Phase

    func handleScenePhase(old: ScenePhase, new: ScenePhase) {
        let appPhase = AppScenePhase(new)
        if backgroundPolicy.shouldStopTraining(newPhase: appPhase) {
            Self.logger.info("App leaving active state (\(String(describing: new))) — stopping active session")
            stopCurrentSession()
        }
        if appPhase == .active && shouldAutoStartTraining
            && currentTrainingDestination != nil && !isTrainingActive {
            #if os(macOS)
            // Don't auto-restart behind an open Settings/Help window. macOS-only:
            // on iOS this keeps scene-phase behavior byte-identical to before, and
            // the help sheet already covers the surface either way.
            if isForegroundSuspended { return }
            #endif
            Self.logger.info("App returned to active — auto-restarting training")
            startCurrentSession()
        }
    }

    // MARK: - macOS App Activation (NSApplication notifications)

    func handleAppDeactivated() {
        Self.logger.info("App deactivated — stopping current session")
        stopCurrentSession()
    }

    func handleAppActivated() {
        guard shouldAutoStartTraining,
              currentTrainingDestination != nil,
              !isTrainingActive,
              !isForegroundSuspended else { return }
        Self.logger.info("App activated — auto-restarting training")
        startCurrentSession()
    }

    // MARK: - Training Screen Lifecycle

    func trainingScreenAppeared(destination: NavigationDestination) {
        if pausedDestination == destination {
            currentTrainingDestination = destination
            registry.contribution(for: destination)?.reconcile()
            pausedDestination = nil
        } else {
            discardLingeringPausedSession()
            currentTrainingDestination = destination
            // Don't auto-start behind an open auxiliary window — e.g. switching
            // disciplines on macOS while the Settings or Help window stays open
            // must leave the new discipline suspended until that window closes.
            if shouldAutoStartTraining && !isForegroundSuspended {
                startCurrentSession()
            }
        }
    }

    func trainingScreenDisappeared() {
        guard let destination = currentTrainingDestination,
              let session = registry.contribution(for: destination)?.session,
              !session.isIdle else {
            currentTrainingDestination = nil
            return
        }
        discardLingeringPausedSession()
        pausedDestination = destination
        session.pause()
        currentTrainingDestination = nil
    }

    /// Pop-to-Start signal — nav-push and nav-pop produce identical
    /// `onDisappear` events at the modifier level, so without this hook a
    /// paused session would linger until another lifecycle event arrived.
    func startScreenAppeared() {
        discardLingeringPausedSession()
    }

    func helpSheetPresented() {
        suspendForeground(.helpWindow)
    }

    func helpSheetDismissed() {
        // `autoStartIfIdle`: on the iOS sheet path the session may have ended
        // while help was up; auto-start it again if policy allows.
        releaseForeground(.helpWindow, autoStartIfIdle: true)
    }

    /// Suspends the foreground training session when the macOS Settings window
    /// opens. The training window stays up while the user edits settings in the
    /// separate Settings window, so without this its session keeps looping
    /// audibly behind Settings. Pausing (not stopping) preserves the current
    /// trial so the paired `reconcileForegroundSession()` on window dismissal
    /// resumes it (settings unchanged) or restarts it fresh (settings changed).
    ///
    /// No-op when no training is foreground (`currentTrainingDestination == nil`,
    /// e.g. Settings opened from Start). iOS has no separate Settings window;
    /// there the pushed Settings screen covers the training screen and pauses
    /// via `trainingScreenDisappeared`.
    func pauseForegroundSession() {
        suspendForeground(.settingsWindow)
    }

    /// Releases the macOS Settings window's suspension. Reconciles the foreground
    /// session with the current settings — restarting if anything changed,
    /// resuming the preserved trial otherwise — but only once the Help window
    /// (if also open) has released its suspension too. The training window stays
    /// up while the user edits settings, so reconciling on dismissal applies all
    /// the edits at once with no mid-edit restart churn. `autoStartIfIdle: true`
    /// mirrors the Help path: if the foreground discipline ended up idle while
    /// Settings was open (e.g. the user switched disciplines, which suppresses
    /// auto-start while suspended), closing Settings starts it per policy. iOS
    /// has no separate Settings window; there the equivalent reconcile happens in
    /// `trainingScreenAppeared` on return from the pushed Settings screen.
    func reconcileForegroundSession() {
        releaseForeground(.settingsWindow, autoStartIfIdle: true)
    }

    // MARK: - Foreground Suspension (macOS auxiliary windows)

    /// Records that `reason` now suspends the foreground session and pauses it on
    /// the *first* reason. Later reasons are no-ops while already paused, so the
    /// session pauses once no matter how many windows are open. The pause is
    /// recorded in `pausedDestination` (like a navigation pause) so the canonical
    /// `discardLingeringPausedSession()` cleanup terminates it on stop/navigate.
    /// The reason is recorded even with no foreground training (e.g. Settings
    /// opened from Start): `isForegroundSuspended` then suppresses auto-start when
    /// the user enters a discipline while the window is still open, so nothing
    /// plays behind it regardless of which opened first.
    private func suspendForeground(_ reason: ForegroundSuspensionReason) {
        let wasEmpty = foregroundSuspensions.isEmpty
        foregroundSuspensions.insert(reason)
        guard wasEmpty, let session = currentSession, !session.isIdle else { return }
        discardLingeringPausedSession()
        pausedDestination = currentTrainingDestination
        session.pause()
    }

    /// Removes `reason` and reconciles the foreground session only once the last
    /// reason has cleared — while another window still suspends it, it stays
    /// paused. Resume keys off `currentTrainingDestination` (not the pause
    /// bookkeeping), so it is independent of which window opened or closed first.
    /// If the screen was navigated away from (`currentTrainingDestination == nil`),
    /// a navigation pause owns `pausedDestination` — left untouched, honouring
    /// only `autoStartIfIdle`. With a foreground destination present, any
    /// `pausedDestination` is this suspension's own marker (== the foreground
    /// destination), so it is cleared before resuming.
    private func releaseForeground(_ reason: ForegroundSuspensionReason, autoStartIfIdle: Bool) {
        foregroundSuspensions.remove(reason)
        guard foregroundSuspensions.isEmpty else { return }
        guard currentTrainingDestination != nil else {
            if autoStartIfIdle && shouldAutoStartTraining { startCurrentSession() }
            return
        }
        pausedDestination = nil
        if let session = currentSession, !session.isIdle {
            reconcileCurrentForegroundSession()
        } else if autoStartIfIdle && shouldAutoStartTraining {
            startCurrentSession()
        }
    }

    /// Reconciles the current foreground session with its live settings snapshot
    /// (resume if unchanged, restart if changed). No-op when no training is
    /// foreground or the session is idle.
    private func reconcileCurrentForegroundSession() {
        guard let destination = currentTrainingDestination,
              let contribution = registry.contribution(for: destination),
              !contribution.session.isIdle else { return }
        contribution.reconcile()
    }

    func toggleTraining() {
        if isTrainingActive {
            stopCurrentSession()
        } else {
            startCurrentSession()
        }
    }

    func startCurrentSession() {
        guard let destination = currentTrainingDestination else { return }
        discardLingeringPausedSession()
        registry.contribution(for: destination)?.start()
    }

    func stopCurrentSession() {
        discardLingeringPausedSession()
        currentSession?.stop()
    }

    // MARK: - Audio Infrastructure Lifecycle

    /// Called by the centralized iOS audio observer when an interruption OR
    /// a route change (`.oldDeviceUnavailable`) requires stopping playback.
    /// Routes through the canonical session-stop path. PF-055's
    /// `.appWasSuspended` filter happens inside the observer before this
    /// callback fires.
    func handleAudioStopRequired() {
        Self.logger.info("Audio stop requested — stopping current session")
        stopCurrentSession()
    }

    /// Called by the centralized iOS audio observer when `mediaserverd` has
    /// died. Stops the active session immediately — session Tasks reference
    /// `AVAudioUnitSampler` instances that are now dead; continuing would
    /// dispatch MIDI into the void. Then marks `mediaRebuildPending` so the
    /// Reset handler observes the prior-Lost diagnostic state. Rebuilding
    /// before `mediaserverd` respawns would fail, so the engine rebuild waits
    /// for Reset. (PF-057 companion — Story 85.8 Decision C, C5 patch)
    func handleMediaServicesLost() {
        Self.logger.warning("Media services were lost — stopping current session and awaiting reset")
        stopCurrentSession()
        mediaRebuildPending = true
    }

    /// Called by the centralized iOS audio observer when `mediaserverd` has
    /// respawned. Stops the active session via the canonical path, then
    /// rebuilds the audio infrastructure in place. Recovery is silent —
    /// the user perceives the session stop (UI returns to idle) and audio
    /// resumes on the next user-initiated trial. Re-entrant calls coalesce
    /// on the engine side via `rebuildInFlight`. (PF-057, Decision D)
    func handleMediaServicesReset() {
        Self.logger.notice("Media services were reset — stopping session and rebuilding audio infrastructure")
        stopCurrentSession()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await mediaInfrastructureRebuild()
                Self.logger.info("Audio infrastructure rebuilt after media reset")
            } catch {
                Self.logger.error("Audio infrastructure rebuild after media reset failed: \(error.localizedDescription)")
            }
            mediaRebuildPending = false
        }
    }

    // MARK: - Sound Source Change

    /// Called by the composition root when the sound source changes. Stops
    /// every non-idle registered session — mid-trial audio would straddle two
    /// instruments otherwise. Discarding the lingering paused session (if any)
    /// clears `pausedDestination`; `foregroundSuspensions` and
    /// `currentTrainingDestination` deliberately survive, so an open auxiliary
    /// window keeps suppressing auto-start and closing it (or returning to the
    /// training screen) starts the stopped session fresh per policy.
    func handleSoundSourceChanged() {
        // Count before stopping: `.onChange` also fires on @AppStorage sync at
        // launch, when everything is idle and nothing stops — stay silent then.
        let nonIdleCount = registry.all.count { !$0.session.isIdle }
        if nonIdleCount > 0 {
            Self.logger.info("Sound source changed — stopping \(nonIdleCount) non-idle session(s)")
        }
        discardLingeringPausedSession()
        for contribution in registry.all where !contribution.session.isIdle {
            contribution.session.stop()
        }
    }

    /// Stops the tracked paused session (if any) and clears the pause
    /// bookkeeping. Idempotent. Two kinds of caller: navigation/lifecycle
    /// events discarding a pause for a no-longer-current destination, and
    /// `handleSoundSourceChanged`, which discards a pause whose destination IS
    /// still current — the preserved trial straddles two instruments and must
    /// not resume.
    private func discardLingeringPausedSession() {
        guard let dest = pausedDestination,
              let paused = registry.contribution(for: dest)?.session else {
            pausedDestination = nil
            return
        }
        paused.stop()
        pausedDestination = nil
    }

    // MARK: - Menu Navigation

    func navigate(to destination: NavigationDestination) {
        navigationTask?.cancel()
        navigationTask = Task {
            discardLingeringPausedSession()
            if let session = activeSession, !session.isIdle {
                session.stop()
                await awaitIdle(of: session)
            }
            guard !Task.isCancelled else { return }
            Self.logger.info("Menu navigation resolved to \(String(describing: destination))")
            resolvedNavigation = NavigationRequest(destination: destination)
        }
    }

    /// Suspends until `session.isIdle` becomes `true`.
    ///
    /// PF-047 defensive shape: the read of `session.isIdle` is performed INSIDE
    /// the `withObservationTracking` block, and a synchronous re-check decides
    /// whether to resume immediately or wait for the next mutation. This
    /// eliminates the read-then-suspend race window for any future
    /// async-`isIdle` migration — under the current synchronous
    /// MainActor-readable `isIdle`, the race is not reachable, but the
    /// defensive pattern locks the contract in place. See PF-047 audit in
    /// `docs/implementation-artifacts/85-3-audit-and-harden-sequencer-concurrency.md`.
    ///
    /// Honors Task cancellation: `withCheckedContinuation` does NOT integrate
    /// with cancellation on its own, so the continuation is wrapped in
    /// `withTaskCancellationHandler`. On cancel, the `SingleShotResumerBox` is
    /// resumed so the await returns; the caller's subsequent `Task.isCancelled`
    /// check propagates the cancellation.
    private func awaitIdle(of session: any TrainingSession) async {
        while !session.isIdle {
            if Task.isCancelled { return }
            // Hoist `SingleShotResumerBox` out so both the observation block's
            // resume paths AND `onCancel` can target the same one-shot guard.
            // The lock-wrapped continuation is set on demand inside
            // `withCheckedContinuation`'s body.
            let resumeBox = SingleShotResumerBox()
            await withTaskCancellationHandler {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    resumeBox.install(continuation: continuation)
                    withObservationTracking {
                        // Re-check inside the tracking block: if idle is already
                        // true at this point, resume immediately rather than
                        // installing the observer for a mutation that already
                        // happened. The `_ = session.isIdle` read in the else
                        // branch is what registers the observer for the next
                        // mutation.
                        if session.isIdle {
                            resumeBox.resume()
                        } else {
                            _ = session.isIdle
                        }
                    } onChange: {
                        resumeBox.resume()
                    }
                }
            } onCancel: {
                // Release the await so the caller's Task.isCancelled check
                // can propagate the cancellation. The box guarantees at-most-
                // once resume across all paths.
                resumeBox.resume()
            }
            if Task.isCancelled { return }
        }
    }
}

/// One-shot wrapper around `CheckedContinuation` for `withObservationTracking`
/// patterns where multiple paths — the synchronous re-check inside the tracking
/// block, the asynchronous `onChange`, AND the `withTaskCancellationHandler`'s
/// `onCancel` — may attempt to resume the same continuation. Resuming a
/// `CheckedContinuation` twice traps; the single-shot guard makes the order
/// between the paths irrelevant.
///
/// The box is allocated BEFORE `withCheckedContinuation` so the cancellation
/// handler (which is set up outside the continuation) can reach it; the
/// continuation is `install`ed once it exists. `resume()` is a no-op until
/// installation, which keeps `onCancel` safe to fire at any point — including
/// before the continuation body runs.
///
/// `onChange` and `onCancel` may run on whichever isolation context dispatches
/// them; the type is `nonisolated` and uses an `OSAllocatedUnfairLock` so the
/// guard is safe regardless of caller isolation.
///
/// **Sendable safety rationale.** Per the Swift Concurrency Continuation
/// contract, `CheckedContinuation.resume()` is documented as thread-safe and
/// may be invoked from any isolation domain. The lock-wrapped optional
/// guarantees at most one path observes a non-nil continuation, so the
/// at-most-once invariant the continuation requires is preserved across
/// cross-isolation callers. The combination of `nonisolated` + a lock-wrapped
/// `CheckedContinuation<Void, Never>?` therefore satisfies `Sendable` without
/// requiring `@unchecked`.
nonisolated private final class SingleShotResumerBox: Sendable {
    private let state: OSAllocatedUnfairLock<State>

    private enum State {
        /// Continuation not yet installed AND no resume requested.
        case pending
        /// Continuation installed and still waiting to be resumed.
        case armed(CheckedContinuation<Void, Never>)
        /// A resume was requested before the continuation was installed; the
        /// installation will resume immediately.
        case resumeRequested
        /// Already resumed; further calls are no-ops.
        case consumed
    }

    init() {
        self.state = OSAllocatedUnfairLock(initialState: .pending)
    }

    /// Install the continuation. If `resume()` was already called — or, in
    /// the pathological double-install case, if a prior continuation already
    /// completed — the incoming continuation resumes immediately. Resuming
    /// rather than swallowing avoids the `CheckedContinuation` leak trap on
    /// the incoming continuation if `install()` is ever reached from an
    /// unexpected path.
    func install(continuation: CheckedContinuation<Void, Never>) {
        let shouldResumeNow: Bool = state.withLock { storage in
            switch storage {
            case .pending:
                storage = .armed(continuation)
                return false
            case .resumeRequested, .consumed:
                storage = .consumed
                return true
            case .armed:
                // Two live continuations cannot share one box; this is a logic
                // bug. The new continuation resumes so it doesn't trap; the
                // old one is left to be resumed by some other path (or trap
                // and surface the bug).
                assertionFailure("SingleShotResumerBox.install called twice with two live continuations")
                return true
            }
        }
        if shouldResumeNow {
            continuation.resume()
        }
    }

    func resume() {
        let toResume: CheckedContinuation<Void, Never>? = state.withLock { storage in
            switch storage {
            case .pending:
                storage = .resumeRequested
                return nil
            case .armed(let continuation):
                storage = .consumed
                return continuation
            case .resumeRequested, .consumed:
                return nil
            }
        }
        toResume?.resume()
    }
}
