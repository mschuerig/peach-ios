import Foundation
import Observation
import os

enum PitchComparisonSessionState {
    case idle
    case playingNote1
    case playingNote2
    case awaitingAnswer
    case showingFeedback
}

@Observable
final class PitchComparisonSession: TrainingSession {
    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "PitchComparisonSession")

    // MARK: - Observable State

    private(set) var state: PitchComparisonSessionState = .idle
    private(set) var showFeedback: Bool = false
    private(set) var isLastAnswerCorrect: Bool? = nil
    private(set) var sessionBestCentDifference: Cents? = nil
    private(set) var currentInterval: DirectedInterval? = nil

    // MARK: - Dependencies

    private let notePlayer: NotePlayer
    private let strategy: NextPitchComparisonStrategy
    private let profile: PitchComparisonProfile
    private let resettables: [Resettable]
    private let observers: [PitchComparisonObserver]
    private var interruptionMonitor: AudioSessionInterruptionMonitor?

    // MARK: - Configuration

    private let userSettings: UserSettings

    private var currentSettings: TrainingSettings {
        TrainingSettings(
            noteRange: userSettings.noteRange,
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

    private let velocity: MIDIVelocity = TrainingConstants.velocity

    private let feedbackDuration: Duration = TrainingConstants.feedbackDuration

    // MARK: - Training State

    private var currentPitchComparison: PitchComparison?
    private var lastCompletedPitchComparison: CompletedPitchComparison?
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var sessionIntervals: Set<DirectedInterval> = []
    private(set) var sessionTuningSystem: TuningSystem = .equalTemperament

    // MARK: - Initialization

    init(
        notePlayer: NotePlayer,
        strategy: NextPitchComparisonStrategy,
        profile: PitchComparisonProfile,
        userSettings: UserSettings,
        resettables: [Resettable] = [],
        observers: [PitchComparisonObserver] = [],
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

    var isIntervalMode: Bool {
        guard let current = currentInterval else { return false }
        return current.interval != .prime
    }

    var currentDifficulty: Cents? {
        currentPitchComparison.map { Cents($0.targetNote.offset.magnitude) }
    }

    var lastCompletedCentDifference: Cents? {
        lastCompletedPitchComparison.map { Cents($0.pitchComparison.targetNote.offset.magnitude) }
    }

    func start(intervals: Set<DirectedInterval>) {
        guard state == .idle else {
            logger.warning("start() called but state is \(String(describing: self.state)), not idle")
            return
        }

        precondition(!intervals.isEmpty, "intervals must not be empty")
        sessionIntervals = intervals
        sessionTuningSystem = userSettings.tuningSystem

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
        guard let pitchComparison = currentPitchComparison else {
            logger.error("handleAnswer() called but currentPitchComparison is nil")
            return
        }

        logger.info("User answered: \(isHigher ? "HIGHER" : "LOWER")")

        stopTargetNoteIfPlaying()

        let completed = CompletedPitchComparison(pitchComparison: pitchComparison, userAnsweredHigher: isHigher, tuningSystem: sessionTuningSystem)
        logger.info("Answer was \(completed.isCorrect ? "✓ CORRECT" : "✗ WRONG") (target was \(pitchComparison.isTargetHigher ? "higher" : "lower"))")

        lastCompletedPitchComparison = completed
        trackSessionBest(completed)
        recordPitchComparison(completed)
        transitionToFeedback(completed)
    }

    func resetTrainingData() throws {
        if state != .idle {
            stop()
        }

        lastCompletedPitchComparison = nil
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
        currentPitchComparison = nil
        lastCompletedPitchComparison = nil
        sessionBestCentDifference = nil
        currentInterval = nil
        sessionIntervals = []
        sessionTuningSystem = .equalTemperament

        showFeedback = false
        isLastAnswerCorrect = nil
    }

    // MARK: - Private Implementation

    private func runTrainingLoop() async {
        logger.info("runTrainingLoop() started")

        await playNextPitchComparison()

        while state != .idle && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
        }

        logger.info("runTrainingLoop() ended, state: \(String(describing: self.state))")
    }

    private func playNextPitchComparison() async {
        let settings = currentSettings
        let noteDuration = currentNoteDuration

        let interval = sessionIntervals.randomElement()!
        currentInterval = interval

        let pitchComparison = strategy.nextPitchComparison(
            profile: profile,
            settings: settings,
            lastPitchComparison: lastCompletedPitchComparison,
            interval: interval
        )
        currentPitchComparison = pitchComparison

        let amplitudeDB = calculateTargetAmplitude(varyLoudness: currentVaryLoudness)

        do {
            try await playPitchComparisonNotes(
                pitchComparison: pitchComparison,
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

    private func calculateTargetAmplitude(varyLoudness: Double) -> AmplitudeDB {
        guard varyLoudness > 0.0 else { return AmplitudeDB(0.0) }
        let range = Float(varyLoudness) * maxLoudnessOffsetDB
        let offset = Float.random(in: -range...range)
        return AmplitudeDB(offset)
    }

    private func playPitchComparisonNotes(
        pitchComparison: PitchComparison,
        settings: TrainingSettings,
        noteDuration: TimeInterval,
        amplitudeDB: AmplitudeDB
    ) async throws {
        let freq1 = pitchComparison.referenceFrequency(tuningSystem: sessionTuningSystem, referencePitch: settings.referencePitch)
        let freq2 = pitchComparison.targetFrequency(tuningSystem: sessionTuningSystem, referencePitch: settings.referencePitch)
        logger.info("PitchComparison: ref=\(pitchComparison.referenceNote.rawValue) \(freq1.rawValue)Hz @0.0dB, target \(freq2.rawValue)Hz @\(amplitudeDB.rawValue)dB, offset=\(pitchComparison.targetNote.offset.rawValue), higher=\(pitchComparison.isTargetHigher)")

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

    private func stopTargetNoteIfPlaying() {
        let wasPlayingTargetNote = (state == .playingNote2)
        if wasPlayingTargetNote {
            logger.info("Stopping note 2 immediately")
            Task {
                try? await notePlayer.stopAll()
            }
        }
    }

    private func trackSessionBest(_ completed: CompletedPitchComparison) {
        guard completed.isCorrect else { return }
        let diff = Cents(completed.pitchComparison.targetNote.offset.magnitude)
        if let best = sessionBestCentDifference {
            if diff < best { sessionBestCentDifference = diff }
        } else {
            sessionBestCentDifference = diff
        }
    }

    private func transitionToFeedback(_ completed: CompletedPitchComparison) {
        isLastAnswerCorrect = completed.isCorrect
        showFeedback = true

        state = .showingFeedback
        logger.info("Entering feedback state")

        feedbackTask = Task {
            try? await Task.sleep(for: feedbackDuration)
            if state == .showingFeedback && !Task.isCancelled {
                showFeedback = false
                logger.info("Feedback complete, starting next comparison")
                await playNextPitchComparison()
            }
        }
    }

    private func recordPitchComparison(_ completed: CompletedPitchComparison) {
        observers.forEach { observer in
            observer.pitchComparisonCompleted(completed)
        }
    }

}
