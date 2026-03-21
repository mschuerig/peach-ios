import Foundation
import Observation
import os

enum PitchDiscriminationSessionState {
    case idle
    case playingNote1
    case playingNote2
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
    private var interruptionMonitor: AudioSessionInterruptionMonitor?

    // MARK: - Training State

    private var settings: PitchDiscriminationSettings?
    private var currentTrial: PitchDiscriminationTrial?
    private var lastCompletedTrial: CompletedPitchDiscriminationTrial?
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

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
        notificationCenter: NotificationCenter = .default
    ) {
        self.notePlayer = notePlayer
        self.strategy = strategy
        self.profile = profile
        self.resettables = resettables
        self.observers = observers
        self.interruptionMonitor = AudioSessionInterruptionMonitor(
            notificationCenter: notificationCenter,
            logger: logger,
            onStopRequired: { [weak self] in self?.stop() }
        )
    }

    // MARK: - Public API

    var isIdle: Bool { state == .idle }

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
        trainingTask = Task {
            await runTrainingLoop()
        }
    }

    func handleAnswer(isHigher: Bool) {
        guard state == .awaitingAnswer || state == .playingNote2 else {
            logger.warning("handleAnswer() called but state is \(String(describing: self.state))")
            return
        }
        guard let trial = currentTrial else {
            logger.error("handleAnswer() called but currentTrial is nil")
            return
        }

        logger.info("User answered: \(isHigher ? "HIGHER" : "LOWER")")

        stopTargetNoteIfPlaying()

        let completed = CompletedPitchDiscriminationTrial(trial: trial, userAnsweredHigher: isHigher, tuningSystem: sessionTuningSystem)
        logger.info("Answer was \(completed.isCorrect ? "✓ CORRECT" : "✗ WRONG") (target was \(trial.isTargetHigher ? "higher" : "lower"))")

        lastCompletedTrial = completed
        trackSessionBest(completed)
        recordTrial(completed)
        transitionToFeedback(completed)
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

        trainingTask?.cancel()
        trainingTask = nil
        feedbackTask?.cancel()
        feedbackTask = nil

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

        state = .playingNote1
        try await notePlayer.play(frequency: freq1, duration: .seconds(settings.noteDuration.rawValue), velocity: settings.velocity, amplitudeDB: AmplitudeDB(0.0))

        guard state != .idle && !Task.isCancelled else {
            logger.info("Training stopped during note 1, aborting comparison")
            return
        }

        if settings.noteGap > .zero {
            try await Task.sleep(for: settings.noteGap)
            guard state != .idle && !Task.isCancelled else {
                logger.info("Training stopped during note gap, aborting comparison")
                return
            }
        }

        state = .playingNote2
        try await notePlayer.play(frequency: freq2, duration: .seconds(settings.noteDuration.rawValue), velocity: settings.velocity, amplitudeDB: amplitudeDB)

        guard state != .idle && !Task.isCancelled else {
            logger.info("Training stopped during note 2, aborting comparison")
            return
        }

        if state == .playingNote2 {
            state = .awaitingAnswer
            logger.info("Note 2 finished, awaiting answer")
        } else {
            logger.info("Note 2 finished, but user already answered (state: \(String(describing: self.state)))")
        }
    }

    private func stopTargetNoteIfPlaying() {
        let wasPlayingTargetNote = (state == .playingNote2)
        if wasPlayingTargetNote {
            logger.info("Stopping note 2 immediately")
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

    private func transitionToFeedback(_ completed: CompletedPitchDiscriminationTrial) {
        guard let settings else { return }

        isLastAnswerCorrect = completed.isCorrect
        showFeedback = true

        state = .showingFeedback
        logger.info("Entering feedback state")

        feedbackTask = Task {
            try? await Task.sleep(for: settings.feedbackDuration)
            if state == .showingFeedback && !Task.isCancelled {
                showFeedback = false
                logger.info("Feedback complete, starting next comparison")
                await playNextTrial()
            }
        }
    }

    private func recordTrial(_ completed: CompletedPitchDiscriminationTrial) {
        observers.forEach { observer in
            observer.pitchDiscriminationCompleted(completed)
        }
    }

}
