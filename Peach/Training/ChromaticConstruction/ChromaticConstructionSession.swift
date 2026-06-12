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
    /// positions, advances to the next position and plays the just-committed
    /// pitch as the orienting cue. For the final interior position, the trial
    /// completes implicitly and the session transitions to `.showingResult`.
    func place(offset: Cents) {
        guard state == .walking, var trial = currentTrial else {
            logger.debug("place(offset:) ignored — not in .walking")
            return
        }
        trial.place(offset: offset)
        currentTrial = trial
        if trial.isComplete {
            notePlayer.scheduleStopAll()
            state = .showingResult
            lastCompletedTrial = CompletedChromaticConstructionTrial(trial: trial, timestamp: Date())
            logger.info("Trial complete; advancing to .showingResult")
        } else {
            playOrientingCueForCurrentActivePosition()
        }
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
        settings = nil
        currentTrial = nil
        lastCompletedTrial = nil
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
        playCue(at: cueFrequency)
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
                logger.error("Audio error during orienting cue: \(error.localizedDescription, privacy: .public)")
            }
        })
    }
}
