import Foundation
import Observation
import os

enum ChromaticConstructionSessionState: Equatable {
    case idle
    case walking(activeSlot: Slot, committed: [Slot], ladder: Ladder)
    case showingResult(ladder: Ladder, committed: [Slot])
}

@Observable
final class ChromaticConstructionSession: TrainingSession {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "ChromaticConstructionSession")

    // MARK: - Observable State

    private(set) var state: ChromaticConstructionSessionState = .idle

    // MARK: - Dependencies

    private let notePlayer: any NotePlayer
    private var lifecycle: SessionLifecycle?

    // MARK: - Trial State

    private var settings: ChromaticConstructionSettings?
    private var isPaused = false

    // MARK: - Initialization

    init(notePlayer: any NotePlayer) {
        self.notePlayer = notePlayer
        self.lifecycle = SessionLifecycle(logger: logger)
    }

    // MARK: - TrainingSession Protocol

    var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    func stop() {
        guard !isIdle else { return }
        logger.info("Session stopped")
        isPaused = false
        lifecycle?.cancelAllTasks()
        notePlayer.scheduleStopAll()
        settings = nil
        state = .idle
    }

    func pause() {
        guard !isPaused, !isIdle else { return }
        isPaused = true
        lifecycle?.cancelAllTasks()
        notePlayer.scheduleStopAll()
        logger.info("Session paused (preserving state \(String(describing: self.state)))")
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        guard case .walking = state else {
            logger.info("Session resume called outside .walking; no audio re-engagement")
            return
        }
        logger.info("Session resuming, re-engaging orienting cue")
        playOrientingCueForCurrentActiveSlot()
    }

    // MARK: - Trial Inputs

    /// Starts a fresh trial. The session must be idle.
    func start(settings: ChromaticConstructionSettings) {
        guard isIdle else {
            logger.warning("start() called but state is \(String(describing: self.state)), not idle")
            return
        }
        self.settings = settings
        let firstSlot = Slot(index: 1, state: .active, placedCents: nil)
        state = .walking(activeSlot: firstSlot, committed: [], ladder: settings.ladder)
        logger.info("Trial started: ladder slotCount=\(settings.ladder.slotCount)")
        playOrientingCueForCurrentActiveSlot()
    }

    /// Commits the active slot with the given cent value. For interior slots,
    /// advances to the next slot and plays the just-committed pitch as the
    /// orienting cue. For the final slot, transitions to `.showingResult`
    /// with no orienting cue (implicit submit per spec).
    func place(cents: Cents) {
        guard case .walking(let activeSlot, let committed, let ladder) = state else {
            logger.debug("place(cents:) ignored — not in .walking")
            return
        }
        let committedSlot = activeSlot.committing(at: cents)
        let nextCommitted = committed + [committedSlot]
        if activeSlot.index == ladder.slotCount {
            // Final slot — implicit submit, no orienting cue.
            logger.info("Final slot committed; advancing to .showingResult")
            notePlayer.scheduleStopAll()
            state = .showingResult(ladder: ladder, committed: nextCommitted)
            return
        }
        // Interior slot — advance and cue the just-committed pitch.
        let nextSlot = Slot(index: activeSlot.index + 1, state: .active, placedCents: nil)
        state = .walking(activeSlot: nextSlot, committed: nextCommitted, ladder: ladder)
        playOrientingCueForCurrentActiveSlot()
    }

    /// Lossy step-back: re-activates the immediately previous slot, preserving
    /// its `placedCents` as the slider's starting position. Any forward slots
    /// (already implicitly `.pending` because they aren't in `committed`) stay
    /// `.pending`. In `.showingResult`, returns to `.walking` at the final
    /// slot with its placedCents preserved.
    func stepBack() {
        switch state {
        case .walking(let activeSlot, let committed, let ladder):
            guard activeSlot.index > 1, let prior = committed.last else {
                logger.debug("stepBack at slot 1 is a no-op")
                return
            }
            let revivedSlot = prior.reactivated()  // preserves placedCents
            state = .walking(
                activeSlot: revivedSlot,
                committed: Array(committed.dropLast()),
                ladder: ladder
            )
            playOrientingCueForCurrentActiveSlot()

        case .showingResult(let ladder, let committed):
            guard let prior = committed.last else {
                logger.debug("stepBack from showingResult with empty committed; no-op")
                return
            }
            let revivedSlot = prior.reactivated()
            state = .walking(
                activeSlot: revivedSlot,
                committed: Array(committed.dropLast()),
                ladder: ladder
            )
            playOrientingCueForCurrentActiveSlot()

        case .idle:
            logger.debug("stepBack while idle is a no-op")
        }
    }

    /// Returns to `.idle` from `.showingResult` so the screen can call
    /// `start(settings:)` with a fresh ladder. Audio stops.
    func nextTrial() {
        guard case .showingResult = state else {
            logger.debug("nextTrial ignored — not in .showingResult")
            return
        }
        notePlayer.scheduleStopAll()
        settings = nil
        state = .idle
    }

    // MARK: - Audio

    private func playOrientingCueForCurrentActiveSlot() {
        guard case .walking(let activeSlot, let committed, let ladder) = state,
              let settings else { return }

        let cueFrequency: Frequency
        if activeSlot.index == 1 {
            cueFrequency = ladder.lowerAnchor.frequency(
                in: ladder.tuningSystem,
                referencePitch: settings.referencePitch
            )
        } else {
            // Predecessor pitch: lowerAnchor * 2^(predecessorCents / 1200).
            guard let predecessor = committed.last,
                  let predecessorCents = predecessor.placedCents else {
                logger.warning("Cannot compute predecessor cue: committed.last has no placedCents")
                return
            }
            let lowerAnchorFreq = ladder.lowerAnchor.frequency(
                in: ladder.tuningSystem,
                referencePitch: settings.referencePitch
            )
            cueFrequency = lowerAnchorFreq * pow(2.0, predecessorCents / Cents.perOctave)
        }
        playCue(at: cueFrequency)
    }

    private func playCue(at frequency: Frequency) {
        notePlayer.scheduleStopAll()
        lifecycle?.setTrainingTask(Task {
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
                logger.error("Audio error during orienting cue: \(error.localizedDescription)")
            }
        })
    }
}
