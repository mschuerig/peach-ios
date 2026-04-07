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

    // MARK: - State Machine Types

    enum Event {
        case startRequested
        case referencePhaseCompleted
        case targetNoteFinished
        case answerReceived(isHigher: Bool)
        case feedbackTimerFired
        case stopRequested
        case audioError
    }

    enum Effect {
        case beginNextTrial
        case playTargetNote
        case stopNote
        case evaluateAnswer(isHigher: Bool)
        case scheduleFeedbackTimer
        case stopAll
    }

    /// Pure state transition function. Given the current state and an event,
    /// produces the new state and a list of effects to execute.
    static func reduce(state: inout PitchDiscriminationSessionState, event: Event) -> [Effect] {
        switch (state, event) {
        case (.idle, .startRequested):
            state = .playingReferenceNote
            return [.beginNextTrial]

        case (.playingReferenceNote, .referencePhaseCompleted):
            state = .playingTargetNote
            return [.playTargetNote]

        case (.playingTargetNote, .targetNoteFinished):
            state = .awaitingAnswer
            return []

        case (.playingTargetNote, .answerReceived(let isHigher)):
            state = .showingFeedback
            return [.stopNote, .evaluateAnswer(isHigher: isHigher), .scheduleFeedbackTimer]

        case (.awaitingAnswer, .answerReceived(let isHigher)):
            state = .showingFeedback
            return [.evaluateAnswer(isHigher: isHigher), .scheduleFeedbackTimer]

        case (.showingFeedback, .feedbackTimerFired):
            state = .playingReferenceNote
            return [.beginNextTrial]

        case (.idle, .stopRequested):
            return []

        case (_, .stopRequested):
            state = .idle
            return [.stopAll]

        case (_, .audioError):
            state = .idle
            return [.stopAll]

        default:
            return []
        }
    }

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
        send(.startRequested)
    }

    @discardableResult
    func handleAnswer(isHigher: Bool) -> Bool {
        guard currentTrial != nil else {
            logger.warning("handleAnswer() called but currentTrial is nil")
            return false
        }
        logger.info("User answered: \(isHigher ? "HIGHER" : "LOWER")")
        let previousState = state
        send(.answerReceived(isHigher: isHigher))
        return state != previousState
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
        send(.stopRequested)
    }

    // MARK: - State Machine Engine

    private func send(_ event: Event) {
        let previousState = state
        let effects = Self.reduce(state: &state, event: event)
        if state == previousState && effects.isEmpty && !isNoOpTransition(event) {
            logger.warning("Invalid transition: \(String(describing: event)) in state \(String(describing: previousState))")
        }
        for effect in effects {
            interpret(effect)
        }
    }

    private func isNoOpTransition(_ event: Event) -> Bool {
        if case .stopRequested = event { return true }
        return false
    }

    // MARK: - Effect Interpreter

    private func interpret(_ effect: Effect) {
        switch effect {
        case .beginNextTrial:
            beginNextTrial()

        case .playTargetNote:
            playTargetNote()

        case .stopNote:
            logger.info("Stopping target note immediately")
            Task {
                try? await notePlayer.stopAll()
            }

        case .evaluateAnswer(let isHigher):
            evaluateAnswer(isHigher: isHigher)

        case .scheduleFeedbackTimer:
            scheduleFeedbackTimer()

        case .stopAll:
            stopAll()
        }
    }

    // MARK: - Effect Implementations

    private func beginNextTrial() {
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

        let freq1 = trial.referenceFrequency(tuningSystem: settings.tuningSystem, referencePitch: settings.referencePitch)
        let freq2 = trial.targetFrequency(tuningSystem: settings.tuningSystem, referencePitch: settings.referencePitch)
        logger.info("PitchDiscriminationTrial: ref=\(trial.referenceNote.rawValue) \(freq1.rawValue)Hz, target \(freq2.rawValue)Hz, offset=\(trial.targetNote.offset.rawValue), higher=\(trial.isTargetHigher)")

        lifecycle?.setTrainingTask(Task {
            do {
                try await notePlayer.play(
                    frequency: freq1,
                    duration: .seconds(settings.noteDuration.rawValue),
                    velocity: settings.velocity,
                    amplitudeDB: AmplitudeDB(0.0)
                )

                guard state != .idle && !Task.isCancelled else {
                    logger.info("Training stopped during reference note, aborting")
                    return
                }

                if settings.noteGap > .zero {
                    try await Task.sleep(for: settings.noteGap)
                    guard state != .idle && !Task.isCancelled else {
                        logger.info("Training stopped during note gap, aborting")
                        return
                    }
                }

                send(.referencePhaseCompleted)
            } catch is CancellationError {
                logger.info("Training task cancelled")
            } catch {
                logger.error("Audio error during reference note: \(error.localizedDescription)")
                send(.audioError)
            }
        })
    }

    private func playTargetNote() {
        guard let settings, let trial = currentTrial else { return }

        let amplitudeDB = calculateTargetAmplitude()
        let freq2 = trial.targetFrequency(tuningSystem: settings.tuningSystem, referencePitch: settings.referencePitch)

        lifecycle?.setTrainingTask(Task {
            do {
                try await notePlayer.play(
                    frequency: freq2,
                    duration: .seconds(settings.noteDuration.rawValue),
                    velocity: settings.velocity,
                    amplitudeDB: amplitudeDB
                )

                guard state != .idle && !Task.isCancelled else {
                    logger.info("Training stopped during target note, aborting")
                    return
                }

                if state == .playingTargetNote {
                    send(.targetNoteFinished)
                } else {
                    logger.info("Target note finished, but user already answered (state: \(String(describing: self.state)))")
                }
            } catch is CancellationError {
                logger.info("Training task cancelled")
            } catch {
                logger.error("Audio error during target note: \(error.localizedDescription)")
                send(.audioError)
            }
        })
    }

    private func evaluateAnswer(isHigher: Bool) {
        guard let trial = currentTrial else { return }

        let completed = CompletedPitchDiscriminationTrial(
            trial: trial, userAnsweredHigher: isHigher, tuningSystem: sessionTuningSystem
        )
        logger.info("Answer was \(completed.isCorrect ? "✓ CORRECT" : "✗ WRONG") (target was \(trial.isTargetHigher ? "higher" : "lower"))")

        lastCompletedTrial = completed
        trackSessionBest(completed)

        isLastAnswerCorrect = completed.isCorrect
        showFeedback = true

        observers.forEach { observer in
            observer.pitchDiscriminationCompleted(completed)
        }
    }

    private func scheduleFeedbackTimer() {
        guard let settings else { return }
        logger.info("Entering feedback state")

        lifecycle?.setFeedbackTask(Task {
            try? await Task.sleep(for: settings.feedbackDuration)
            guard state == .showingFeedback && !Task.isCancelled else { return }
            showFeedback = false
            logger.info("Feedback complete, starting next comparison")
            send(.feedbackTimerFired)
        })
    }

    private func stopAll() {
        logger.info("Training stopped (state was transitioning to idle)")

        Task {
            try? await notePlayer.stopAll()
            logger.info("NotePlayer stopped")
        }

        lifecycle?.cancelAllTasks()

        currentTrial = nil
        lastCompletedTrial = nil
        sessionBestCentDifference = nil
        currentInterval = nil
        settings = nil
        showFeedback = false
        isLastAnswerCorrect = nil
    }

    // MARK: - Private Helpers

    private func calculateTargetAmplitude() -> AmplitudeDB {
        guard let settings else { return AmplitudeDB(0.0) }
        let varyLoudness = settings.varyLoudness.rawValue
        guard varyLoudness > 0.0 else { return AmplitudeDB(0.0) }
        let range = varyLoudness * settings.maxLoudnessOffsetDB.rawValue
        let offset = Double.random(in: -range...range)
        return AmplitudeDB(offset)
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
}
