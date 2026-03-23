import Foundation
import Observation
import QuartzCore
import os

enum RhythmOffsetDetectionSessionState {
    case idle
    case playingPattern
    case awaitingAnswer
    case showingFeedback
    case waitingForGrid
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
    private let currentTime: () -> Double
    private var interruptionMonitor: AudioSessionInterruptionMonitor?

    // MARK: - Training State

    private var settings: RhythmOffsetDetectionSettings?
    private var currentTrial: RhythmOffsetDetectionTrial?
    private var lastCompletedTrial: CompletedRhythmOffsetDetectionTrial?
    private var currentHandle: RhythmPlaybackHandle?
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var gridOrigin: Double?

    var currentOffsetPercentage: Double? {
        guard let trial = currentTrial else { return nil }
        return trial.offset.percentageOfSixteenthNote(at: trial.tempo)
    }

    var lastCompletedOffsetPercentage: Double? {
        guard let trial = lastCompletedTrial else { return nil }
        return trial.offset.percentageOfSixteenthNote(at: trial.tempo)
    }

    var lastCompletedOffsetMs: Double? {
        lastCompletedTrial?.offset.absoluteMilliseconds
    }

    // MARK: - Initialization

    init(
        rhythmPlayer: RhythmPlayer,
        strategy: NextRhythmOffsetDetectionStrategy,
        profile: TrainingProfile,
        observers: [RhythmOffsetDetectionObserver] = [],
        sampleRate: SampleRate,
        notificationCenter: NotificationCenter = .default,
        currentTime: @escaping () -> Double = { CACurrentMediaTime() }
    ) {
        self.rhythmPlayer = rhythmPlayer
        self.strategy = strategy
        self.profile = profile
        self.observers = observers
        self.sampleRate = sampleRate
        self.currentTime = currentTime
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
            let ms = trial.offset.absoluteMilliseconds
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
        gridOrigin = nil

        showFeedback = false
        isLastAnswerCorrect = nil
        litDotCount = 0
        sessionBestOffsetPercentage = nil
        sessionBestOffsetMs = nil
    }

    // MARK: - Private Implementation

    private func nextGridPoint(quarterNoteDuration: Double) -> Double {
        guard let gridOrigin else { return currentTime() }
        let now = currentTime()
        let elapsed = now - gridOrigin
        let n = ceil(elapsed / quarterNoteDuration)
        return gridOrigin + n * quarterNoteDuration
    }

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

        // Record grid origin on first pattern
        if gridOrigin == nil {
            gridOrigin = currentTime()
            logger.info("Grid origin established at \(self.gridOrigin!)")
        }

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

    /// Index of the note that receives the timing offset (0-based among 4 sixteenth notes).
    private static let testedNoteIndex = 2

    private func buildPattern(for trial: RhythmOffsetDetectionTrial, settings: RhythmOffsetDetectionSettings) -> RhythmPattern {
        let sixteenthDuration = settings.tempo.sixteenthNoteDuration
        let samplesPerSixteenth = Int64(sampleRate.rawValue * sixteenthDuration.timeInterval)

        let clickNote = MIDINote(76)
        let velocity = MIDIVelocity(100)
        let offsetSamples = Int64(sampleRate.rawValue * trial.offset.duration.timeInterval)

        var events = (0..<4).map { i in
            let base = Int64(i) * samplesPerSixteenth
            let offset = (i == Self.testedNoteIndex) ? offsetSamples : 0
            return RhythmPattern.Event(
                sampleOffset: base + offset,
                midiNote: clickNote,
                velocity: velocity
            )
        }

        events.sort { $0.sampleOffset < $1.sampleOffset }

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
            guard state == .showingFeedback && !Task.isCancelled else { return }

            showFeedback = false

            // Wait for next grid point before playing next trial
            let quarterDuration = settings.tempo.quarterNoteDuration.timeInterval
            let gridPoint = nextGridPoint(quarterNoteDuration: quarterDuration)
            let now = currentTime()
            let waitTime = gridPoint - now

            if waitTime > 0 {
                litDotCount = 0
                state = .waitingForGrid
                logger.info("Waiting \(waitTime)s for grid alignment")
                try? await Task.sleep(for: .seconds(waitTime))
                guard state == .waitingForGrid && !Task.isCancelled else { return }
            }

            logger.info("Grid-aligned, starting next trial")
            await playNextTrial()
        }
    }

    private func recordTrial(_ completed: CompletedRhythmOffsetDetectionTrial) {
        observers.forEach { observer in
            observer.rhythmOffsetDetectionCompleted(completed)
        }
    }
}
