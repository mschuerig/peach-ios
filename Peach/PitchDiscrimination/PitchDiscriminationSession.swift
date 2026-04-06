import Foundation
import Observation
import os

enum PitchDiscriminationSessionState {
    case idle
    case playingReferenceNote
    case playingTargetNote
    case awaitingAnswer
    case showingFeedback
}

@Observable
final class PitchDiscriminationSession: TrainingSession {
    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "PitchDiscriminationSession")

    // MARK: - Observable State

    private(set) var state: PitchDiscriminationSessionState = .idle
    private(set) var showFeedback: Bool = false
    private(set) var isLastAnswerCorrect: Bool? = nil
    private(set) var sessionBestCentDifference: Cents? = nil
    private(set) var currentInterval: DirectedInterval? = nil

    // MARK: - Dependencies

    private let notePlayer: NotePlayer
    private let strategy: NextPitchDiscriminationStrategy
    private let profile: TrainingProfile
    private let resettables: [Resettable]
    private let observers: [PitchDiscriminationObserver]
    private var lifecycle: SessionLifecycle?

    // MARK: - Training State

    private var settings: PitchDiscriminationSettings?
    private var currentTrial: PitchDiscriminationTrial?
    private var lastCompletedTrial: CompletedPitchDiscriminationTrial?

    var sessionTuningSystem: TuningSystem {
        settings?.tuningSystem ?? .equalTemperament
    }

    // MARK: - Initialization

    init(
        notePlayer: NotePlayer,
        strategy: NextPitchDiscriminationStrategy,
        profile: TrainingProfile,
        resettables: [Resettable] = [],
        observers: [PitchDiscriminationObserver] = [],
        notificationCenter: NotificationCenter = .default,
        audioInterruptionObserver: AudioInterruptionObserving,
        backgroundNotificationName: Notification.Name? = nil,
        foregroundNotificationName: Notification.Name? = nil
    ) {
        self.notePlayer = notePlayer
        self.strategy = strategy
        self.profile = profile
        self.resettables = resettables
        self.observers = observers
        self.lifecycle = SessionLifecycle(
            logger: logger,
            notificationCenter: notificationCenter,
            audioInterruptionObserver: audioInterruptionObserver,
            backgroundNotificationName: backgroundNotificationName,
            foregroundNotificationName: foregroundNotificationName,
            onStopRequired: { [weak self] in self?.stop() }
        )
    }

    // MARK: - Public API

    var isIdle: Bool { state == .idle }

    var canAcceptAnswer: Bool { state == .playingTargetNote || state == .awaitingAnswer }

    /// Handles a letter-key shortcut by matching against localized Higher/Lower keys.
    /// Returns `true` if the key matched and the answer was accepted.
    @discardableResult
    func handleShortcutKey(_ character: String) -> Bool {
        let char = character.lowercased()
        let higherKey = String(localized: "shortcut.higher").lowercased()
        let lowerKey = String(localized: "shortcut.lower").lowercased()
        if char == higherKey {
            return handleAnswer(isHigher: true)
        } else if char == lowerKey {
            return handleAnswer(isHigher: false)
        }
        return false
    }


    var isIntervalMode: Bool {
        guard let current = currentInterval else { return false }
        return current.interval != .prime
    }

    var currentDifficulty: Cents? {
        currentTrial.map { Cents($0.targetNote.offset.magnitude) }
    }

    var lastCompletedCentDifference: Cents? {
        lastCompletedTrial.map { Cents($0.trial.targetNote.offset.magnitude) }
    }

    func start(settings: PitchDiscriminationSettings) {
        guard state == .idle else {
            logger.warning("start() called but state is \(String(describing: self.state)), not idle")
            return
        }

        precondition(!settings.intervals.isEmpty, "intervals must not be empty")
        self.settings = settings

        logger.info("Starting training loop")
        lifecycle?.setTrainingTask(Task {
            await runTrainingLoop()
        })
    }

    @discardableResult
    func handleAnswer(isHigher: Bool) -> Bool {
        guard state == .awaitingAnswer || state == .playingTargetNote else {
            logger.warning("handleAnswer() called but state is \(String(describing: self.state))")
            return false
        }
        guard let trial = currentTrial else {
            logger.warning("handleAnswer() called but currentTrial is nil")
            return false
        }

        logger.info("User answered: \(isHigher ? "HIGHER" : "LOWER")")

        stopTargetNoteIfPlaying()

        let completed = CompletedPitchDiscriminationTrial(trial: trial, userAnsweredHigher: isHigher, tuningSystem: sessionTuningSystem)
        logger.info("Answer was \(completed.isCorrect ? "✓ CORRECT" : "✗ WRONG") (target was \(trial.isTargetHigher ? "higher" : "lower"))")

        lastCompletedTrial = completed
        trackSessionBest(completed)
        recordTrial(completed)
        transitionToFeedback(completed)
        return true
    }

    func resetTrainingData() throws {
        if state != .idle {
            stop()
        }

        lastCompletedTrial = nil
        sessionBestCentDifference = nil
        for resettable in resettables {
            try resettable.reset()
        }

        logger.info("Training data reset to cold start")
    }

    func stop() {
        guard state != .idle else {
            logger.debug("stop() called but already idle")
            return
        }

        logger.info("Training stopped (state was: \(String(describing: self.state)))")

        Task {
            try? await notePlayer.stopAll()
            logger.info("NotePlayer stopped")
        }

        lifecycle?.cancelAllTasks()

        state = .idle
        currentTrial = nil
        lastCompletedTrial = nil
        sessionBestCentDifference = nil
        currentInterval = nil
        settings = nil

        showFeedback = false
        isLastAnswerCorrect = nil
    }

    // MARK: - Private Implementation

    private func runTrainingLoop() async {
        logger.info("runTrainingLoop() started")

        await playNextTrial()

        while state != .idle && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
        }

        logger.info("runTrainingLoop() ended, state: \(String(describing: self.state))")
    }

    private func playNextTrial() async {
        guard let settings else { return }

        guard let interval = settings.intervals.randomElement() else { return }
        currentInterval = interval

        let trial = strategy.nextPitchDiscriminationTrial(
            profile: profile,
            settings: settings,
            lastTrial: lastCompletedTrial,
            interval: interval
        )
        currentTrial = trial

        let amplitudeDB = calculateTargetAmplitude()

        do {
            try await playTrialNotes(
                trial: trial,
                amplitudeDB: amplitudeDB
            )
        } catch is CancellationError {
            logger.info("Training task cancelled")
        } catch let error as AudioError {
            logger.error("Audio error, stopping training: \(error.localizedDescription)")
            stop()
        } catch {
            logger.error("Unexpected error, stopping training: \(error.localizedDescription)")
            stop()
        }
    }

    private func calculateTargetAmplitude() -> AmplitudeDB {
        guard let settings else { return AmplitudeDB(0.0) }
        let varyLoudness = settings.varyLoudness.rawValue
        guard varyLoudness > 0.0 else { return AmplitudeDB(0.0) }
        let range = varyLoudness * settings.maxLoudnessOffsetDB.rawValue
        let offset = Double.random(in: -range...range)
        return AmplitudeDB(offset)
    }

    private func playTrialNotes(
        trial: PitchDiscriminationTrial,
        amplitudeDB: AmplitudeDB
    ) async throws {
        guard let settings else { return }

        let freq1 = trial.referenceFrequency(tuningSystem: settings.tuningSystem, referencePitch: settings.referencePitch)
        let freq2 = trial.targetFrequency(tuningSystem: settings.tuningSystem, referencePitch: settings.referencePitch)
        logger.info("PitchDiscriminationTrial: ref=\(trial.referenceNote.rawValue) \(freq1.rawValue)Hz @0.0dB, target \(freq2.rawValue)Hz @\(amplitudeDB.rawValue)dB, offset=\(trial.targetNote.offset.rawValue), higher=\(trial.isTargetHigher)")

        state = .playingReferenceNote
        try await notePlayer.play(frequency: freq1, duration: .seconds(settings.noteDuration.rawValue), velocity: settings.velocity, amplitudeDB: AmplitudeDB(0.0))

        guard state != .idle && !Task.isCancelled else {
            logger.info("Training stopped during reference note, aborting comparison")
            return
        }

        if settings.noteGap > .zero {
            try await Task.sleep(for: settings.noteGap)
            guard state != .idle && !Task.isCancelled else {
                logger.info("Training stopped during note gap, aborting comparison")
                return
            }
        }

        state = .playingTargetNote
        try await notePlayer.play(frequency: freq2, duration: .seconds(settings.noteDuration.rawValue), velocity: settings.velocity, amplitudeDB: amplitudeDB)

        guard state != .idle && !Task.isCancelled else {
            logger.info("Training stopped during target note, aborting comparison")
            return
        }

        if state == .playingTargetNote {
            state = .awaitingAnswer
            logger.info("Target note finished, awaiting answer")
        } else {
            logger.info("Target note finished, but user already answered (state: \(String(describing: self.state)))")
        }
    }

    private func stopTargetNoteIfPlaying() {
        if state == .playingTargetNote {
            logger.info("Stopping target note immediately")
            Task {
                try? await notePlayer.stopAll()
            }
        }
    }

    private func trackSessionBest(_ completed: CompletedPitchDiscriminationTrial) {
        guard completed.isCorrect else { return }
        let diff = Cents(completed.trial.targetNote.offset.magnitude)
        if let best = sessionBestCentDifference {
            if diff < best { sessionBestCentDifference = diff }
        } else {
            sessionBestCentDifference = diff
        }
    }

    // WALKTHROUGH: Named "transitionToFeedback" but also plays the next trial.
    // State machine transitions are interwoven with side effects (recording, feedback, scheduling).
    // See observation #3 in Layer 3 notes — research explicit state machine patterns.
    private func transitionToFeedback(_ completed: CompletedPitchDiscriminationTrial) {
        guard let settings else { return }

        isLastAnswerCorrect = completed.isCorrect
        showFeedback = true

        state = .showingFeedback
        logger.info("Entering feedback state")

        lifecycle?.setFeedbackTask(Task {
            try? await Task.sleep(for: settings.feedbackDuration)
            if state == .showingFeedback && !Task.isCancelled {
                showFeedback = false
                logger.info("Feedback complete, starting next comparison")
                await playNextTrial()
            }
        })
    }

    private func recordTrial(_ completed: CompletedPitchDiscriminationTrial) {
        observers.forEach { observer in
            observer.pitchDiscriminationCompleted(completed)
        }
    }

}
