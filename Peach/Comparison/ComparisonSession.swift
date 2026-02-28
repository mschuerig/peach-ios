import Foundation
import Observation
import os

enum ComparisonSessionState {
    case idle
    case playingNote1
    case playingNote2
    case awaitingAnswer
    case showingFeedback
}

@Observable
final class ComparisonSession: TrainingSession {
    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "ComparisonSession")

    // MARK: - Observable State

    private(set) var state: ComparisonSessionState = .idle
    private(set) var showFeedback: Bool = false
    private(set) var isLastAnswerCorrect: Bool? = nil
    private(set) var sessionBestCentDifference: Double? = nil

    // MARK: - Dependencies

    private let notePlayer: NotePlayer
    private let strategy: NextComparisonStrategy
    private let profile: PitchDiscriminationProfile
    private let resettables: [Resettable]
    private let observers: [ComparisonObserver]
    private var interruptionMonitor: AudioSessionInterruptionMonitor?

    // MARK: - Configuration

    private let userSettings: UserSettings

    private var currentSettings: TrainingSettings {
        TrainingSettings(
            noteRangeMin: userSettings.noteRangeMin,
            noteRangeMax: userSettings.noteRangeMax,
            referencePitch: userSettings.referencePitch
        )
    }

    private var currentNoteDuration: TimeInterval {
        userSettings.noteDuration.rawValue
    }

    private var currentVaryLoudness: Double {
        userSettings.varyLoudness.rawValue
    }

    private let maxLoudnessOffsetDB: Float = 5.0

    private let velocity: MIDIVelocity = 63

    private let feedbackDuration: TimeInterval = 0.4

    // MARK: - Training State

    private var currentComparison: Comparison?
    private var lastCompletedComparison: CompletedComparison?
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        notePlayer: NotePlayer,
        strategy: NextComparisonStrategy,
        profile: PitchDiscriminationProfile,
        userSettings: UserSettings,
        resettables: [Resettable] = [],
        observers: [ComparisonObserver] = [],
        notificationCenter: NotificationCenter = .default
    ) {
        self.notePlayer = notePlayer
        self.strategy = strategy
        self.profile = profile
        self.userSettings = userSettings
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

    var currentDifficulty: Double? {
        currentComparison?.centDifference.magnitude
    }

    func startTraining() {
        guard state == .idle else {
            logger.warning("startTraining() called but state is \(String(describing: self.state)), not idle")
            return
        }

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
        guard let comparison = currentComparison else {
            logger.error("handleAnswer() called but currentComparison is nil")
            return
        }

        logger.info("User answered: \(isHigher ? "HIGHER" : "LOWER")")

        stopNote2IfPlaying()

        let completed = CompletedComparison(comparison: comparison, userAnsweredHigher: isHigher)
        logger.info("Answer was \(completed.isCorrect ? "✓ CORRECT" : "✗ WRONG") (second note was \(comparison.isSecondNoteHigher ? "higher" : "lower"))")

        lastCompletedComparison = completed
        trackSessionBest(completed)
        recordComparison(completed)
        transitionToFeedback(completed)
    }

    func resetTrainingData() throws {
        if state != .idle {
            stop()
        }

        lastCompletedComparison = nil
        sessionBestCentDifference = nil
        profile.reset()
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
        currentComparison = nil
        lastCompletedComparison = nil
        sessionBestCentDifference = nil

        showFeedback = false
        isLastAnswerCorrect = nil
    }

    // MARK: - Private Implementation

    private func runTrainingLoop() async {
        logger.info("runTrainingLoop() started")

        await playNextComparison()

        while state != .idle && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
        }

        logger.info("runTrainingLoop() ended, state: \(String(describing: self.state))")
    }

    private func playNextComparison() async {
        let settings = currentSettings
        let noteDuration = currentNoteDuration

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: settings,
            lastComparison: lastCompletedComparison
        )
        currentComparison = comparison

        let amplitudeDB = calculateNote2Amplitude(varyLoudness: currentVaryLoudness)

        do {
            try await playComparisonNotes(
                comparison: comparison,
                settings: settings,
                noteDuration: noteDuration,
                amplitudeDB: amplitudeDB
            )
        } catch let error as AudioError {
            logger.error("Audio error, stopping training: \(error.localizedDescription)")
            stop()
        } catch {
            logger.error("Unexpected error, stopping training: \(error.localizedDescription)")
            stop()
        }
    }

    private func calculateNote2Amplitude(varyLoudness: Double) -> AmplitudeDB {
        guard varyLoudness > 0.0 else { return AmplitudeDB(0.0) }
        let range = Float(varyLoudness) * maxLoudnessOffsetDB
        let offset = Float.random(in: -range...range)
        return AmplitudeDB(offset)
    }

    private func playComparisonNotes(
        comparison: Comparison,
        settings: TrainingSettings,
        noteDuration: TimeInterval,
        amplitudeDB: AmplitudeDB
    ) async throws {
        let freq1 = comparison.note1Frequency(tuningSystem: .equalTemperament, referencePitch: settings.referencePitch)
        let freq2 = comparison.note2Frequency(tuningSystem: .equalTemperament, referencePitch: settings.referencePitch)
        logger.info("Comparison: note1=\(comparison.note1.rawValue) \(freq1.rawValue)Hz @0.0dB, note2 \(freq2.rawValue)Hz @\(amplitudeDB.rawValue)dB, centDiff=\(comparison.centDifference.rawValue), higher=\(comparison.isSecondNoteHigher)")

        state = .playingNote1
        try await notePlayer.play(frequency: freq1, duration: noteDuration, velocity: velocity, amplitudeDB: AmplitudeDB(0.0))

        guard state != .idle && !Task.isCancelled else {
            logger.info("Training stopped during note 1, aborting comparison")
            return
        }

        state = .playingNote2
        try await notePlayer.play(frequency: freq2, duration: noteDuration, velocity: velocity, amplitudeDB: amplitudeDB)

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

    private func stopNote2IfPlaying() {
        let wasPlayingNote2 = (state == .playingNote2)
        if wasPlayingNote2 {
            logger.info("Stopping note 2 immediately")
            Task {
                try? await notePlayer.stopAll()
            }
        }
    }

    private func trackSessionBest(_ completed: CompletedComparison) {
        guard completed.isCorrect else { return }
        let diff = completed.comparison.centDifference.magnitude
        if let best = sessionBestCentDifference {
            if diff < best { sessionBestCentDifference = diff }
        } else {
            sessionBestCentDifference = diff
        }
    }

    private func transitionToFeedback(_ completed: CompletedComparison) {
        isLastAnswerCorrect = completed.isCorrect
        showFeedback = true

        state = .showingFeedback
        logger.info("Entering feedback state (duration: \(self.feedbackDuration)s)")

        feedbackTask = Task {
            try? await Task.sleep(for: .milliseconds(Int(feedbackDuration * 1000)))
            if state == .showingFeedback && !Task.isCancelled {
                showFeedback = false
                logger.info("Feedback complete, starting next comparison")
                await playNextComparison()
            }
        }
    }

    private func recordComparison(_ completed: CompletedComparison) {
        observers.forEach { observer in
            observer.comparisonCompleted(completed)
        }
    }

}
