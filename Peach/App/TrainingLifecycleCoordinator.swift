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

    /// Destination whose session was paused by a transient lifecycle event
    /// (training-screen disappear, help-sheet present). Tracking the
    /// destination instead of the session instance avoids coupling to the
    /// registry's instance-identity guarantee.
    private var pausedDestination: NavigationDestination?

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
              !isTrainingActive else { return }
        Self.logger.info("App activated — auto-restarting training")
        startCurrentSession()
    }

    // MARK: - Training Screen Lifecycle

    func trainingScreenAppeared(destination: NavigationDestination) {
        if pausedDestination == destination {
            currentTrainingDestination = destination
            registry.contribution(for: destination)?.session.resume()
            pausedDestination = nil
        } else {
            discardLingeringPausedSession()
            currentTrainingDestination = destination
            if shouldAutoStartTraining {
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
        guard let destination = currentTrainingDestination,
              let session = registry.contribution(for: destination)?.session,
              !session.isIdle else { return }
        discardLingeringPausedSession()
        pausedDestination = destination
        session.pause()
    }

    func helpSheetDismissed() {
        if let pausedDest = pausedDestination,
           let paused = registry.contribution(for: pausedDest)?.session {
            paused.resume()
            pausedDestination = nil
        } else if shouldAutoStartTraining {
            startCurrentSession()
        }
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

    /// Stops any session paused for a no-longer-current destination. Idempotent.
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
