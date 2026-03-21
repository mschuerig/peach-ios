import Foundation
import Observation
import os

enum RhythmOffsetDetectionSessionState {
    case idle
    case playingPattern
    case awaitingAnswer
    case showingFeedback
}

@Observable
final class RhythmOffsetDetectionSession: TrainingSession {
    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "RhythmOffsetDetectionSession")

    // MARK: - Observable State

    private(set) var state: RhythmOffsetDetectionSessionState = .idle
    private(set) var showFeedback: Bool = false
    private(set) var isLastAnswerCorrect: Bool? = nil
    private(set) var litDotCount: Int = 0
    private(set) var sessionBestOffsetPercentage: Double? = nil
    private(set) var sessionBestOffsetMs: Double? = nil

    // MARK: - Dependencies

    private let rhythmPlayer: RhythmPlayer
    private let strategy: NextRhythmOffsetDetectionStrategy
    private let profile: TrainingProfile
    private let observers: [RhythmOffsetDetectionObserver]
    private let sampleRate: SampleRate
    private var interruptionMonitor: AudioSessionInterruptionMonitor?

    // MARK: - Training State

    private var settings: RhythmOffsetDetectionSettings?
    private var currentTrial: RhythmOffsetDetectionTrial?
    private var lastCompletedTrial: CompletedRhythmOffsetDetectionTrial?
    private var currentHandle: RhythmPlaybackHandle?
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    var currentOffsetPercentage: Double? {
        guard let trial = currentTrial else { return nil }
        return trial.offset.percentageOfSixteenthNote(at: trial.tempo)
    }

    var lastCompletedOffsetPercentage: Double? {
        guard let trial = lastCompletedTrial else { return nil }
        return trial.offset.percentageOfSixteenthNote(at: trial.tempo)
    }

    var lastCompletedOffsetMs: Double? {
        guard let trial = lastCompletedTrial else { return nil }
        let absDuration = trial.offset.duration < .zero ? .zero - trial.offset.duration : trial.offset.duration
        return Double(absDuration.components.attoseconds) / 1e15
    }

    // MARK: - Initialization

    init(
        rhythmPlayer: RhythmPlayer,
        strategy: NextRhythmOffsetDetectionStrategy,
        profile: TrainingProfile,
        observers: [RhythmOffsetDetectionObserver] = [],
        sampleRate: SampleRate,
        notificationCenter: NotificationCenter = .default
    ) {
        self.rhythmPlayer = rhythmPlayer
        self.strategy = strategy
        self.profile = profile
        self.observers = observers
        self.sampleRate = sampleRate
        self.interruptionMonitor = AudioSessionInterruptionMonitor(
            notificationCenter: notificationCenter,
            logger: logger,
            onStopRequired: { [weak self] in self?.stop() }
        )
    }

    // MARK: - Public API

    var isIdle: Bool { state == .idle }

    func start(settings: RhythmOffsetDetectionSettings) {
        guard state == .idle else {
            logger.warning("start() called but state is \(String(describing: self.state)), not idle")
            return
        }

        self.settings = settings
        logger.info("Starting rhythm offset detection training loop")

        trainingTask = Task {
            await runTrainingLoop()
        }
    }

    func handleAnswer(direction: RhythmDirection) {
        guard state == .awaitingAnswer else {
            logger.warning("handleAnswer() called but state is \(String(describing: self.state))")
            return
        }
        guard let trial = currentTrial, let settings else {
            logger.error("handleAnswer() called but currentTrial or settings is nil")
            return
        }

        let isCorrect = (direction == trial.offset.direction)
        logger.info("User answered: \(String(describing: direction)), correct: \(isCorrect)")

        let completed = CompletedRhythmOffsetDetectionTrial(
            tempo: trial.tempo,
            offset: trial.offset,
            isCorrect: isCorrect
        )

        lastCompletedTrial = completed

        if isCorrect {
            let pct = trial.offset.percentageOfSixteenthNote(at: trial.tempo)
            let absDuration = trial.offset.duration < .zero ? .zero - trial.offset.duration : trial.offset.duration
            let ms = Double(absDuration.components.attoseconds) / 1e15
            if let best = sessionBestOffsetPercentage {
                if pct < best {
                    sessionBestOffsetPercentage = pct
                    sessionBestOffsetMs = ms
                }
            } else {
                sessionBestOffsetPercentage = pct
                sessionBestOffsetMs = ms
            }
        }

        recordTrial(completed)
        transitionToFeedback(settings: settings)
    }

    func stop() {
        guard state != .idle else {
            logger.debug("stop() called but already idle")
            return
        }

        logger.info("Training stopped (state was: \(String(describing: self.state)))")

        Task {
            try? await currentHandle?.stop()
            try? await rhythmPlayer.stopAll()
        }

        trainingTask?.cancel()
        trainingTask = nil
        feedbackTask?.cancel()
        feedbackTask = nil

        state = .idle
        currentTrial = nil
        lastCompletedTrial = nil
        currentHandle = nil
        settings = nil

        showFeedback = false
        isLastAnswerCorrect = nil
        litDotCount = 0
        sessionBestOffsetPercentage = nil
        sessionBestOffsetMs = nil
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

        let trial = strategy.nextRhythmOffsetDetectionTrial(
            profile: profile,
            settings: settings,
            lastResult: lastCompletedTrial
        )
        currentTrial = trial

        let pattern = buildPattern(for: trial, settings: settings)

        do {
            state = .playingPattern
            litDotCount = 0
            let handle = try await rhythmPlayer.play(pattern)
            currentHandle = handle

            guard state != .idle && !Task.isCancelled else {
                logger.info("Training stopped during pattern playback, aborting")
                return
            }

            // Animate dots at note onset times
            let sixteenthDuration = settings.tempo.sixteenthNoteDuration
            for i in 0..<4 {
                guard state != .idle && !Task.isCancelled else { return }
                litDotCount = i + 1
                if i < 3 {
                    try await Task.sleep(for: sixteenthDuration)
                }
            }
            // Wait remaining time for 4th note to ring
            try await Task.sleep(for: sixteenthDuration)

            guard state != .idle && !Task.isCancelled else {
                logger.info("Training stopped after pattern completed, aborting")
                return
            }

            state = .awaitingAnswer
            logger.info("Pattern finished, awaiting answer")
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

    private func buildPattern(for trial: RhythmOffsetDetectionTrial, settings: RhythmOffsetDetectionSettings) -> RhythmPattern {
        let sixteenthDuration = settings.tempo.sixteenthNoteDuration
        let samplesPerSixteenth = Int64(sampleRate.rawValue * sixteenthDuration.timeInterval)

        let clickNote = MIDINote(76)
        let velocity = MIDIVelocity(100)

        var events = (0..<3).map { i in
            RhythmPattern.Event(
                sampleOffset: Int64(i) * samplesPerSixteenth,
                midiNote: clickNote,
                velocity: velocity
            )
        }

        let baseOffset4 = 3 * samplesPerSixteenth
        let offsetSamples = Int64(sampleRate.rawValue * trial.offset.duration.timeInterval)
        events.append(RhythmPattern.Event(
            sampleOffset: baseOffset4 + offsetSamples,
            midiNote: clickNote,
            velocity: velocity
        ))

        return RhythmPattern(
            events: events,
            sampleRate: sampleRate,
            totalDuration: sixteenthDuration * 4
        )
    }

    private func transitionToFeedback(settings: RhythmOffsetDetectionSettings) {
        isLastAnswerCorrect = lastCompletedTrial?.isCorrect
        showFeedback = true

        state = .showingFeedback
        logger.info("Entering feedback state")

        feedbackTask = Task {
            try? await Task.sleep(for: settings.feedbackDuration)
            if state == .showingFeedback && !Task.isCancelled {
                showFeedback = false
                logger.info("Feedback complete, starting next trial")
                await playNextTrial()
            }
        }
    }

    private func recordTrial(_ completed: CompletedRhythmOffsetDetectionTrial) {
        observers.forEach { observer in
            observer.rhythmOffsetDetectionCompleted(completed)
        }
    }
}
