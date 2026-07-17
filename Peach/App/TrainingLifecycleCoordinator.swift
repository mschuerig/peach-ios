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

/// Owns *when* training sessions transition (sessions own the *how*). The
/// decision logic is a pure `reduce(state:event:context:)` state machine
/// mirroring `PitchDiscriminationSession` (Story 75.13): every input method
/// funnels through `send`, which folds the event into `state` and hands the
/// resulting `[Effect]` to the imperative interpreter at the edge. Session
/// calls, navigation, and media-infrastructure rebuild are effects; the
/// hardened async machinery (`awaitIdle`, the media-reset Task) lives only in
/// effect implementations. See `docs/implementation-artifacts/spec-88-1-coordinator-reduce-treatment.md`.
@Observable
final class TrainingLifecycleCoordinator {
    private let registry: TrainingLifecycleRegistry
    private let backgroundPolicy: BackgroundPolicy

    /// Invoked when `mediaServicesWereResetNotification` fires. The production
    /// wiring forwards to `SoundFontEngine.rebuildAfterMediaReset`; tests can
    /// substitute a spy. The coordinator owns the policy ("stop active session,
    /// then rebuild infrastructure") and the closure owns the mechanism.
    private let mediaInfrastructureRebuild: () async throws -> Void

    /// A macOS auxiliary window that holds the foreground training session
    /// suspended while it is open. The two windows can be open at once, so
    /// suspension is multi-owner: the session pauses on the first reason and
    /// only reconciles/resumes once the *last* reason clears.
    enum ForegroundSuspensionReason {
        case settingsWindow
        case helpWindow
    }

    /// The pure lifecycle state folded by `reduce`. A struct (not an enum like
    /// the sessions') because coordinator state is a product of several fields.
    private(set) var state: State

    /// The app's currently-running session, pushed in by `PeachApp` (mirrors its
    /// own `@State`). Read only by the navigation effect, which stops it before
    /// resolving. Not part of the pure `state` — it is injected from outside.
    var activeSession: (any TrainingSession)?

    private(set) var resolvedNavigation: NavigationRequest?
    private var navigationTask: Task<Void, Never>?

    private static let logger = Logger(subsystem: "com.peach.app", category: "Lifecycle")

    init(
        registry: TrainingLifecycleRegistry,
        backgroundPolicy: BackgroundPolicy,
        initialAutoStartSetting: Bool,
        mediaInfrastructureRebuild: @escaping () async throws -> Void
    ) {
        self.registry = registry
        self.backgroundPolicy = backgroundPolicy
        self.mediaInfrastructureRebuild = mediaInfrastructureRebuild
        self.state = State(
            policyAutoStart: backgroundPolicy.shouldAutoStartTraining,
            autoStartSetting: initialAutoStartSetting
        )
    }

    // MARK: - Public State Accessors

    /// True while `mediaServicesWereLost` posted but `mediaServicesWereReset`
    /// has not yet arrived. Diagnostic; the Reset handler is permissive.
    var mediaRebuildPending: Bool { state.mediaRebuildPending }

    var currentTrainingDestination: NavigationDestination? { state.currentTrainingDestination }

    /// True while at least one auxiliary window (Settings or Help) suspends the
    /// foreground training session. The macOS training surface reads this to
    /// make itself non-interactive; otherwise a click (e.g. a Timing Offset
    /// Detection answer button) would resume audio behind the open window. iOS
    /// never adds the `.settingsWindow` reason (its Settings is a pushed screen),
    /// and its Help sheet already covers the surface, so this drives no iOS UI.
    var isForegroundSuspended: Bool { state.isForegroundSuspended }

    /// User preference for auto-starting training (macOS only, persisted via UserDefaults).
    /// On iOS, `backgroundPolicy.shouldAutoStartTraining` is always true, so this has no effect.
    var autoStartSetting: Bool {
        get { state.autoStartSetting }
        set { state.autoStartSetting = newValue }
    }

    private var currentSession: (any TrainingSession)? {
        guard let destination = state.currentTrainingDestination else { return nil }
        return registry.contribution(for: destination)?.session
    }

    var isTrainingActive: Bool {
        guard let session = currentSession else { return false }
        return !session.isIdle
    }

    var shouldAutoStartTraining: Bool { state.shouldAutoStart }

    // MARK: - State Machine Types

    struct State: Equatable {
        /// `BackgroundPolicy.shouldAutoStartTraining`, fixed at init.
        let policyAutoStart: Bool
        var currentTrainingDestination: NavigationDestination?
        /// Destination whose session was paused by a navigation event or an
        /// auxiliary-window suspension. Tracking the destination instead of the
        /// session instance avoids coupling to the registry's identity guarantee.
        var pausedDestination: NavigationDestination?
        var foregroundSuspensions: Set<ForegroundSuspensionReason> = []
        var autoStartSetting: Bool
        var mediaRebuildPending: Bool = false

        var shouldAutoStart: Bool { policyAutoStart || autoStartSetting }
        var isForegroundSuspended: Bool { !foregroundSuspensions.isEmpty }
    }

    enum Event {
        case scenePhaseChanged(AppScenePhase, shouldStop: Bool)
        case appActivated
        case appDeactivated
        case trainingScreenAppeared(NavigationDestination)
        case trainingScreenDisappeared
        case startScreenAppeared
        case foregroundSuspended(ForegroundSuspensionReason)
        case foregroundReleased(ForegroundSuspensionReason, autoStartIfIdle: Bool)
        case toggleRequested
        case startRequested
        case stopRequested
        case audioStopRequired
        case mediaServicesLost
        case mediaServicesReset
        case mediaRebuildCompleted
        case soundSourceChanged
        case navigationRequested(NavigationDestination)
    }

    enum Effect: Equatable {
        case startSession(NavigationDestination)
        case stopSession(NavigationDestination)
        case pauseSession(NavigationDestination)
        case reconcileSession(NavigationDestination)
        case stopAllNonIdleSessions
        case navigate(NavigationDestination)
        case rebuildMediaInfrastructure
    }

    /// Edge-read facts the reducer needs but cannot query purely: whether the
    /// foreground (`currentTrainingDestination`) session is idle. Read once per
    /// `send`. The session owns this bit; the coordinator only observes it.
    struct Context {
        let foregroundSessionIsIdle: Bool
    }

    // MARK: - Reduce (pure)

    /// Pure decision core: folds `event` into `state` and returns the effects to
    /// run at the edge. No `self`, no registry/policy access — only `state`,
    /// `event`, and `context`. Every (state, event) pair is total; unhandled
    /// combinations fall out as an empty effect list (no crash).
    static func reduce(state: inout State, event: Event, context: Context) -> [Effect] {
        switch event {
        case let .scenePhaseChanged(phase, shouldStop):
            var effects: [Effect] = []
            if shouldStop { effects += stopCurrent(&state) }
            // Auto-restart on foreground return, but never behind an open
            // auxiliary window. The `isForegroundSuspended` guard applies on BOTH
            // platforms (PF-079): on iOS the Help sheet suspends the session, so
            // the guard suppresses restarting audio behind the sheet until it is
            // dismissed. `.active` never stops, so the two branches never overlap.
            if phase == .active, state.shouldAutoStart, state.currentTrainingDestination != nil,
               context.foregroundSessionIsIdle, !state.isForegroundSuspended {
                effects += startCurrent(&state)
            }
            return effects

        case .appActivated:
            guard state.shouldAutoStart, state.currentTrainingDestination != nil,
                  context.foregroundSessionIsIdle, !state.isForegroundSuspended else { return [] }
            return startCurrent(&state)

        case .appDeactivated:
            return stopCurrent(&state)

        case let .trainingScreenAppeared(destination):
            if state.pausedDestination == destination {
                state.currentTrainingDestination = destination
                state.pausedDestination = nil
                return [.reconcileSession(destination)]
            }
            var effects = discardLingeringPaused(&state)
            state.currentTrainingDestination = destination
            // Don't auto-start behind an open auxiliary window — e.g. switching
            // disciplines on macOS while Settings/Help stays open must leave the
            // new discipline suspended until that window closes.
            if state.shouldAutoStart, !state.isForegroundSuspended {
                effects += startCurrent(&state)
            }
            return effects

        case .trainingScreenDisappeared:
            guard let destination = state.currentTrainingDestination,
                  !context.foregroundSessionIsIdle else {
                state.currentTrainingDestination = nil
                return []
            }
            var effects = discardLingeringPaused(&state)
            state.pausedDestination = destination
            effects.append(.pauseSession(destination))
            state.currentTrainingDestination = nil
            return effects

        case .startScreenAppeared:
            // Pop-to-Start signal — nav-push and nav-pop produce identical
            // `onDisappear` events, so without this a paused session would linger.
            return discardLingeringPaused(&state)

        case let .foregroundSuspended(reason):
            let wasEmpty = state.foregroundSuspensions.isEmpty
            state.foregroundSuspensions.insert(reason)
            // Pause on the *first* reason only; later reasons are no-ops while
            // already suspended. The reason is still recorded even with no
            // foreground training, so `isForegroundSuspended` suppresses
            // auto-start when the user enters a discipline behind the window.
            guard wasEmpty, let destination = state.currentTrainingDestination,
                  !context.foregroundSessionIsIdle else { return [] }
            var effects = discardLingeringPaused(&state)
            state.pausedDestination = destination
            effects.append(.pauseSession(destination))
            return effects

        case let .foregroundReleased(reason, autoStartIfIdle):
            state.foregroundSuspensions.remove(reason)
            // Reconcile only once the last reason clears.
            guard state.foregroundSuspensions.isEmpty else { return [] }
            guard let destination = state.currentTrainingDestination else {
                // Navigated away — there is no foreground session to start, and a
                // navigation pause (if any) owns `pausedDestination`, so it is
                // left untouched. `autoStartIfIdle` has nothing to act on here.
                return []
            }
            // With a foreground destination present, any `pausedDestination` is
            // this suspension's own marker (== the foreground destination).
            state.pausedDestination = nil
            if !context.foregroundSessionIsIdle {
                return [.reconcileSession(destination)]
            }
            return (autoStartIfIdle && state.shouldAutoStart) ? startCurrent(&state) : []

        case .toggleRequested:
            if state.currentTrainingDestination != nil, !context.foregroundSessionIsIdle {
                return stopCurrent(&state)
            }
            return startCurrent(&state)

        case .startRequested:
            return startCurrent(&state)

        case .stopRequested:
            return stopCurrent(&state)

        case .audioStopRequired:
            return stopCurrent(&state)

        case .mediaServicesLost:
            let effects = stopCurrent(&state)
            state.mediaRebuildPending = true
            return effects

        case .mediaServicesReset:
            var effects = stopCurrent(&state)
            effects.append(.rebuildMediaInfrastructure)
            return effects

        case .mediaRebuildCompleted:
            state.mediaRebuildPending = false
            return []

        case .soundSourceChanged:
            // Discard any paused session (its preserved trial straddles two
            // instruments) then stop every non-idle session. `foregroundSuspensions`
            // and `currentTrainingDestination` deliberately survive.
            var effects = discardLingeringPaused(&state)
            effects.append(.stopAllNonIdleSessions)
            return effects

        case let .navigationRequested(destination):
            var effects = discardLingeringPaused(&state)
            effects.append(.navigate(destination))
            return effects
        }
    }

    /// Stops the tracked paused session (if any) and clears the pause
    /// bookkeeping. Pure: emits the stop effect, mutates only `state`.
    private static func discardLingeringPaused(_ state: inout State) -> [Effect] {
        guard let destination = state.pausedDestination else { return [] }
        state.pausedDestination = nil
        return [.stopSession(destination)]
    }

    private static func startCurrent(_ state: inout State) -> [Effect] {
        guard let destination = state.currentTrainingDestination else { return [] }
        var effects = discardLingeringPaused(&state)
        effects.append(.startSession(destination))
        return effects
    }

    private static func stopCurrent(_ state: inout State) -> [Effect] {
        var effects = discardLingeringPaused(&state)
        if let destination = state.currentTrainingDestination {
            effects.append(.stopSession(destination))
        }
        return effects
    }

    // MARK: - State Machine Engine

    /// Unlike a session's enum state machine, the coordinator's *product* state
    /// has no genuinely-invalid transitions — every event is a valid command
    /// that conditionally emits effects — so there is no "invalid transition"
    /// warning here (it would only ever produce false positives). Never-crash is
    /// structural: `reduce`'s switch is total.
    private func send(_ event: Event) {
        let effects = Self.reduce(state: &state, event: event, context: makeContext())
        for effect in effects { interpret(effect) }
    }

    private func makeContext() -> Context {
        Context(foregroundSessionIsIdle: currentSession?.isIdle ?? true)
    }

    // MARK: - Effect Interpreter

    private func interpret(_ effect: Effect) {
        switch effect {
        case let .startSession(destination):
            registry.contribution(for: destination)?.start()
        case let .stopSession(destination):
            registry.contribution(for: destination)?.session.stop()
        case let .pauseSession(destination):
            registry.contribution(for: destination)?.session.pause()
        case let .reconcileSession(destination):
            registry.contribution(for: destination)?.reconcile()
        case .stopAllNonIdleSessions:
            stopAllNonIdleSessions()
        case let .navigate(destination):
            performNavigation(to: destination)
        case .rebuildMediaInfrastructure:
            rebuildMediaInfrastructure()
        }
    }

    // MARK: - Scene Phase

    func handleScenePhase(old: ScenePhase, new: ScenePhase) {
        let phase = AppScenePhase(new)
        let shouldStop = backgroundPolicy.shouldStopTraining(newPhase: phase)
        if shouldStop {
            Self.logger.info("App leaving active state (\(String(describing: new))) — stopping active session")
        }
        send(.scenePhaseChanged(phase, shouldStop: shouldStop))
    }

    // MARK: - macOS App Activation (NSApplication notifications)

    func handleAppDeactivated() {
        Self.logger.info("App deactivated — stopping current session")
        send(.appDeactivated)
    }

    func handleAppActivated() {
        Self.logger.info("App activated — reconciling training session")
        send(.appActivated)
    }

    // MARK: - Training Screen Lifecycle

    func trainingScreenAppeared(destination: NavigationDestination) {
        send(.trainingScreenAppeared(destination))
    }

    func trainingScreenDisappeared() {
        send(.trainingScreenDisappeared)
    }

    /// Pop-to-Start signal — see `.startScreenAppeared` in `reduce`.
    func startScreenAppeared() {
        send(.startScreenAppeared)
    }

    func helpSheetPresented() {
        send(.foregroundSuspended(.helpWindow))
    }

    func helpSheetDismissed() {
        // The session may have ended while Help was up (iOS sheet path); the
        // release auto-starts it again if policy allows.
        send(.foregroundReleased(.helpWindow, autoStartIfIdle: true))
    }

    /// Suspends the foreground training session when the macOS Settings window
    /// opens, so it stops looping audibly behind Settings. Pausing (not stopping)
    /// preserves the current trial for the paired `reconcileForegroundSession()`.
    /// No-op when no training is foreground; iOS has no separate Settings window.
    func pauseForegroundSession() {
        send(.foregroundSuspended(.settingsWindow))
    }

    /// Releases the macOS Settings window's suspension and reconciles the
    /// foreground session (resume if unchanged, restart if changed) — but only
    /// once the Help window, if also open, has released too. Applying edits on
    /// dismissal avoids mid-edit restart churn.
    func reconcileForegroundSession() {
        send(.foregroundReleased(.settingsWindow, autoStartIfIdle: true))
    }

    func toggleTraining() {
        send(.toggleRequested)
    }

    func startCurrentSession() {
        send(.startRequested)
    }

    func stopCurrentSession() {
        send(.stopRequested)
    }

    // MARK: - Audio Infrastructure Lifecycle

    /// Called by the centralized iOS audio observer when an interruption OR
    /// a route change (`.oldDeviceUnavailable`) requires stopping playback.
    /// PF-055's `.appWasSuspended` filter happens inside the observer first.
    func handleAudioStopRequired() {
        Self.logger.info("Audio stop requested — stopping current session")
        send(.audioStopRequired)
    }

    /// Called when `mediaserverd` has died. Stops the active session immediately
    /// — its Tasks reference now-dead `AVAudioUnitSampler` instances — then marks
    /// `mediaRebuildPending`. Rebuilding before `mediaserverd` respawns would
    /// fail, so the engine rebuild waits for Reset. (Story 85.8, Decision C.)
    func handleMediaServicesLost() {
        Self.logger.warning("Media services were lost — stopping current session and awaiting reset")
        send(.mediaServicesLost)
    }

    /// Called when `mediaserverd` has respawned. Stops the active session, then
    /// rebuilds the audio infrastructure in place (see the effect). Recovery is
    /// silent; audio resumes on the next user-initiated trial. (Story 85.8, D.)
    func handleMediaServicesReset() {
        Self.logger.notice("Media services were reset — stopping session and rebuilding audio infrastructure")
        send(.mediaServicesReset)
    }

    // MARK: - Sound Source Change

    /// Called by the composition root when the sound source changes.
    func handleSoundSourceChanged() {
        send(.soundSourceChanged)
    }

    // MARK: - Menu Navigation

    func navigate(to destination: NavigationDestination) {
        send(.navigationRequested(destination))
    }

    // MARK: - Effect Implementations

    private func stopAllNonIdleSessions() {
        let contributions = registry.all
        // Count before stopping: `.onChange` also fires on @AppStorage sync at
        // launch, when everything is idle and nothing stops — stay silent then.
        let nonIdleCount = contributions.count { !$0.session.isIdle }
        if nonIdleCount > 0 {
            Self.logger.info("Sound source changed — stopping \(nonIdleCount) non-idle session(s)")
        }
        for contribution in contributions where !contribution.session.isIdle {
            contribution.session.stop()
        }
    }

    private func performNavigation(to destination: NavigationDestination) {
        navigationTask?.cancel()
        navigationTask = Task { [weak self] in
            guard let self else { return }
            if let session = activeSession, !session.isIdle {
                session.stop()
                await awaitIdle(of: session)
            }
            guard !Task.isCancelled else { return }
            Self.logger.info("Menu navigation resolved to \(String(describing: destination))")
            resolvedNavigation = NavigationRequest(destination: destination)
        }
    }

    private func rebuildMediaInfrastructure() {
        // Re-entrant calls coalesce on the engine side via `rebuildInFlight`.
        Task { [weak self] in
            guard let self else { return }
            do {
                try await mediaInfrastructureRebuild()
                Self.logger.info("Audio infrastructure rebuilt after media reset")
            } catch {
                Self.logger.error("Audio infrastructure rebuild after media reset failed: \(error.localizedDescription)")
            }
            send(.mediaRebuildCompleted)
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
