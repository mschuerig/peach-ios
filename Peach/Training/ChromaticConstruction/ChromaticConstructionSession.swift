import Foundation
import Observation
import os

enum ChromaticConstructionSessionState: Equatable {
    case idle
    case walking
    case showingResult
}

/// Session for the chromatic-construction discipline.
///
/// Shape follows `PitchDiscriminationSession`: a small state enum, an
/// explicit `Event`/`Effect`/`reduce` split, and trial / completed-trial
/// values held alongside state. Per-trial path construction goes through the
/// injected `NextPathStrategy`; per-trial direction is drawn from the
/// settings' `outerIntervals` via `randomElement()`.
@Observable
final class ChromaticConstructionSession: TrainingSession {

    // MARK: - State Machine Types

    enum Event {
        case startRequested
        case placeRequested(offset: Cents)
        case stepBackRequested
        case nextTrialRequested
        case stopRequested
        case audioError
    }

    enum Effect {
        case beginNextTrial
        case playOrientingCue
        case stopAll
    }

    static func reduce(
        state: inout ChromaticConstructionSessionState,
        event: Event
    ) -> [Effect] {
        switch (state, event) {
        case (.idle, .startRequested):
            state = .walking
            return [.beginNextTrial]

        case (.walking, .placeRequested):
            // Resulting state set by the caller after applying the placement,
            // based on `trial.isComplete`.
            return []

        case (.walking, .stepBackRequested):
            return []

        case (.showingResult, .stepBackRequested):
            state = .walking
            return [.playOrientingCue]

        case (.showingResult, .nextTrialRequested):
            state = .walking
            return [.beginNextTrial]

        case (.idle, .stopRequested), (.idle, .audioError):
            return []

        case (_, .stopRequested), (_, .audioError):
            state = .idle
            return [.stopAll]

        default:
            return []
        }
    }

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "ChromaticConstructionSession")

    // MARK: - Observable State

    private(set) var state: ChromaticConstructionSessionState = .idle
    private(set) var currentTrial: ChromaticConstructionTrial?
    private(set) var lastCompletedTrial: CompletedChromaticConstructionTrial?

    // MARK: - Dependencies

    private let notePlayer: any NotePlayer
    private let strategy: any NextPathStrategy
    private var lifecycle: SessionLifecycle?

    // MARK: - Trial State

    private var settings: ChromaticConstructionSettings?
    private var isPaused = false
    /// Continuous-tone handle held while the user is dragging an active
    /// position's slider. Pattern mirrors `PitchMatchingSession.currentHandle`:
    /// `startContinuousTone(at:)` issues a non-duration-bounded `play(…)`,
    /// stashes the returned handle here, and subsequent
    /// `adjustContinuousTone(to:)` calls reroute the live pitch via
    /// `handle.adjustFrequency(_:)` without re-triggering the note.
    /// `stopContinuousTone()` releases it.
    private var currentHandle: PlaybackHandle?

    // MARK: - Initialization

    init(notePlayer: any NotePlayer, strategy: any NextPathStrategy) {
        self.notePlayer = notePlayer
        self.strategy = strategy
        self.lifecycle = SessionLifecycle(logger: logger)
    }

    // MARK: - TrainingSession Protocol

    var isIdle: Bool { state == .idle }

    func stop() {
        send(.stopRequested)
    }

    func pause() {
        guard !isPaused, !isIdle else { return }
        isPaused = true
        lifecycle?.cancelAllTasks()
        notePlayer.scheduleStopAll()
        currentHandle = nil
        logger.info("Session paused (preserving state \(String(describing: self.state), privacy: .public))")
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        guard state == .walking, currentTrial != nil else {
            logger.info("Session resume called outside .walking; no audio re-engagement")
            return
        }
        logger.info("Session resuming, re-engaging orienting cue")
        playOrientingCueForCurrentActivePosition()
    }

    // MARK: - Trial Inputs

    /// Starts a fresh trial. No-op unless `state == .idle`.
    func start(settings: ChromaticConstructionSettings) {
        guard isIdle else {
            logger.warning("start() called but state is \(String(describing: self.state), privacy: .public), not idle")
            return
        }
        self.settings = settings
        send(.startRequested)
    }

    /// Commits the active position with the given cent offset. For interior
    /// positions, simply advances to the next position — the user already
    /// heard the placed pitch via the continuous tone during their drag,
    /// so no post-place orienting cue is needed (iteration-4 feedback: the
    /// redundant cue was confusing). For the final interior position, the
    /// trial completes implicitly and the session transitions to
    /// `.showingResult`.
    func place(offset: Cents) {
        guard state == .walking, var trial = currentTrial else {
            logger.debug("place(offset:) ignored — not in .walking")
            return
        }
        trial.place(offset: offset)
        currentTrial = trial
        if trial.isComplete {
            notePlayer.scheduleStopAll()
            currentHandle = nil
            state = .showingResult
            lastCompletedTrial = CompletedChromaticConstructionTrial(trial: trial, timestamp: Date())
            logger.info("Trial complete; advancing to .showingResult")
        }
        // No post-place orienting cue: the user heard their placed pitch
        // via the continuous tone during drag, so a redundant cue at the
        // same pitch only confused them (iteration-4 feedback).
    }

    /// Lossy step-back. From `.walking` at position > 1: re-activates the
    /// prior position with its placed value preserved. From `.showingResult`:
    /// re-opens the final interior position for revision. No-op at position 1
    /// and from `.idle`.
    func stepBack() {
        switch state {
        case .walking:
            guard var trial = currentTrial else { return }
            let wasAtFirst = trial.active?.index == 1
            trial.stepBack()
            currentTrial = trial
            guard !wasAtFirst else {
                logger.debug("stepBack at position 1 is a no-op")
                return
            }
            playOrientingCueForCurrentActivePosition()
        case .showingResult:
            guard var trial = currentTrial else { return }
            trial.reopenFinalPosition()
            currentTrial = trial
            lastCompletedTrial = nil
            state = .walking
            playOrientingCueForCurrentActivePosition()
        case .idle:
            logger.debug("stepBack while idle is a no-op")
        }
    }

    /// From `.showingResult`: returns to `.idle` so the screen can re-invoke
    /// `start(settings:)` for the next trial. No-op outside `.showingResult`.
    func nextTrial() {
        guard state == .showingResult else {
            logger.debug("nextTrial ignored — not in .showingResult")
            return
        }
        send(.nextTrialRequested)
    }

    // MARK: - State Machine Engine

    private func send(_ event: Event) {
        let effects = Self.reduce(state: &state, event: event)
        for effect in effects {
            interpret(effect)
        }
    }

    private func interpret(_ effect: Effect) {
        switch effect {
        case .beginNextTrial:
            beginNextTrial()
        case .playOrientingCue:
            playOrientingCueForCurrentActivePosition()
        case .stopAll:
            stopAll()
        }
    }

    // MARK: - Effect Implementations

    private func beginNextTrial() {
        guard let settings else { return }
        guard let outerInterval = settings.outerIntervals.randomElement() else { return }

        let path = try! strategy.chromaticPath(
            lowerAnchor: settings.lowerAnchor,
            outerInterval: outerInterval
        )

        let trial = ChromaticConstructionTrial(path: path)
        currentTrial = trial
        logger.info("Trial started: outerInterval=\(outerInterval.displayName, privacy: .public), interiorPositionCount=\(path.interiorPositionCount)")
        playOrientingCueForCurrentActivePosition()
    }

    private func stopAll() {
        logger.info("Session stopped")
        isPaused = false
        lifecycle?.cancelAllTasks()
        notePlayer.scheduleStopAll()
        currentHandle = nil
        settings = nil
        currentTrial = nil
        lastCompletedTrial = nil
    }

    /// Plays the given frequency for the orienting-cue duration. Used by the
    /// screen for tap-replay of committed positions and result-mode dot taps
    /// (single-shot, ~600 ms). For the user's *live* drag on an active
    /// position's slider, use `startContinuousTone(at:)` /
    /// `adjustContinuousTone(to:)` / `stopContinuousTone()` instead — those
    /// hold the note open and re-pitch it without retriggering.
    func replay(frequency: Frequency) {
        guard state != .idle else { return }
        playCue(at: frequency)
    }

    /// Opens a sustained note at the given frequency, stashing the playback
    /// handle so subsequent `adjustContinuousTone(to:)` calls can re-pitch
    /// the live tone. Mirrors `PitchMatchingSession.startTunablePlayback`'s
    /// shape: synchronous `scheduleStopAll()` cancels any in-flight note,
    /// then a training-task spawns the `play(...)` call and captures the
    /// returned handle on completion. The note's `velocity` and
    /// `amplitudeDB` match the orienting-cue defaults so the tone level
    /// stays continuous across cue → drag transitions.
    func startContinuousTone(at frequency: Frequency) {
        guard state != .idle else { return }
        notePlayer.scheduleStopAll()
        lifecycle?.setTrainingTask(Task { [notePlayer, logger] in
            do {
                let handle = try await notePlayer.play(
                    frequency: frequency,
                    velocity: MIDIVelocity.mezzoPiano,
                    amplitudeDB: AmplitudeDB(0.0)
                )
                guard self.state != .idle, !Task.isCancelled else {
                    Task { try? await handle.stop() }
                    return
                }
                self.currentHandle = handle
            } catch is CancellationError {
                return
            } catch {
                logger.error("Audio error during continuous tone start: \(error.localizedDescription, privacy: .public)")
            }
        })
    }

    /// Re-pitches the live continuous tone (if any) to the given frequency
    /// via `PlaybackHandle.adjustFrequency(_:)`. No retrigger, no
    /// `scheduleStopAll()` — the audio chain stays intact so the user
    /// hears a smooth glide rather than discrete note onsets.
    func adjustContinuousTone(to frequency: Frequency) {
        guard state != .idle, let handle = currentHandle else { return }
        Task {
            try? await handle.adjustFrequency(frequency)
        }
    }

    /// Releases the continuous tone (if any). The handle's `stop()` fades
    /// out the note on the audio chain; the next call to `playCue(at:)`,
    /// `startContinuousTone(at:)`, or `scheduleStopAll()` will register
    /// after this stop completes.
    func stopContinuousTone() {
        let handleToStop = currentHandle
        currentHandle = nil
        Task {
            try? await handleToStop?.stop()
        }
    }

    /// Atomic revert-to: drops every placement at index > k back to pending
    /// and re-activates position k. Routes through `ChromaticConstructionTrial.revertTo`,
    /// which preserves placed[k-1] as the position's slider starting value.
    /// From `.showingResult`, this reopens the trial (drops `lastCompletedTrial`)
    /// and returns the session to `.walking`. The caller is expected to play
    /// any orienting cue via `replay(frequency:)`; this method itself does
    /// not schedule audio.
    func revertTo(positionIndex k: Int) {
        switch state {
        case .walking:
            guard var trial = currentTrial else { return }
            trial.revertTo(positionIndex: k)
            currentTrial = trial
        case .showingResult:
            guard var trial = currentTrial else { return }
            trial.revertTo(positionIndex: k)
            currentTrial = trial
            lastCompletedTrial = nil
            state = .walking
        case .idle:
            return
        }
    }

    // MARK: - Audio

    private func playOrientingCueForCurrentActivePosition() {
        guard state == .walking,
              let trial = currentTrial,
              let active = trial.active,
              let settings else { return }

        let lowerAnchorFreq = TuningSystem.equalTemperament.frequency(
            for: trial.path.lowerAnchor,
            referencePitch: settings.referencePitch
        )

        let cueFrequency: Frequency
        if active.index == 1 {
            cueFrequency = lowerAnchorFreq
        } else {
            // Predecessor pitch: lowerAnchor * 2^(predecessorCents / 1200).
            // By invariant: active.index > 1 implies placed.count >= 1.
            let predecessorCents = trial.placed.last!.offset
            cueFrequency = lowerAnchorFreq * pow(2.0, predecessorCents / Cents.perOctave)
        }
        playDelayedCue(at: cueFrequency)
    }

    /// Plays a single 600 ms note after a brief silence. Used by the
    /// orienting cue path so the cue is perceptibly distinct from the
    /// continuous tone's tail (the user hears a clear silence → re-attack
    /// rather than one continuous note that gets retriggered at the same
    /// pitch). Synchronous `scheduleStopAll()` cleanly cuts any in-flight
    /// audio first; the cue task then sleeps ~150 ms before issuing the
    /// `play(...)`, so the audio chain ends up with: stopAll → ~150 ms of
    /// silence → cue play.
    private func playDelayedCue(at frequency: Frequency) {
        notePlayer.scheduleStopAll()
        lifecycle?.setTrainingTask(Task { [notePlayer, logger] in
            do {
                try await Task.sleep(for: .milliseconds(150))
                guard self.state == .walking, !Task.isCancelled else { return }
                try await notePlayer.play(
                    frequency: frequency,
                    duration: .milliseconds(600),
                    velocity: MIDIVelocity.mezzoPiano,
                    amplitudeDB: AmplitudeDB(0.0)
                )
            } catch is CancellationError {
                return
            } catch {
                logger.error("Audio error during orienting cue: \(error.localizedDescription, privacy: .public)")
            }
        })
    }

    private func playCue(at frequency: Frequency) {
        notePlayer.scheduleStopAll()
        lifecycle?.setTrainingTask(Task { [notePlayer, logger] in
            do {
                try await notePlayer.play(
                    frequency: frequency,
                    duration: .milliseconds(600),
                    velocity: MIDIVelocity.mezzoPiano,
                    amplitudeDB: AmplitudeDB(0.0)
                )
            } catch is CancellationError {
                return
            } catch {
                logger.error("Audio error during tap-replay: \(error.localizedDescription, privacy: .public)")
            }
        })
    }
}
