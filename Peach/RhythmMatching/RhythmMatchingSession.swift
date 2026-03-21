import Foundation
import Observation
import os
import QuartzCore

enum RhythmMatchingSessionState {
    case idle
    case playingLeadIn
    case awaitingTap
    case showingFeedback
}

@Observable
final class RhythmMatchingSession: TrainingSession {
    // MARK: - Logger

    private let logger = Logger(subsystem: "com.peach.app", category: "RhythmMatchingSession")

    // MARK: - Observable State

    private(set) var state: RhythmMatchingSessionState = .idle
    private(set) var showFeedback: Bool = false
    private(set) var litDotCount: Int = 0

    // MARK: - Dependencies

    private let rhythmPlayer: RhythmPlayer
    private let observers: [RhythmMatchingObserver]
    private let sampleRate: SampleRate
    private var interruptionMonitor: AudioSessionInterruptionMonitor?

    // MARK: - Training State

    private var settings: RhythmMatchingSettings?
    private var lastCompletedTrial: CompletedRhythmMatchingTrial?
    private var currentHandle: RhythmPlaybackHandle?
    private var trainingTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var expectedTapTime: Double = 0

    var lastUserOffsetPercentage: Double? {
        guard let trial = lastCompletedTrial else { return nil }
        let pct = trial.userOffset.percentageOfSixteenthNote(at: trial.tempo)
        return trial.userOffset.direction == .early ? -pct : pct
    }

    // MARK: - Initialization

    init(
        rhythmPlayer: RhythmPlayer,
        observers: [RhythmMatchingObserver] = [],
        sampleRate: SampleRate,
        notificationCenter: NotificationCenter = .default
    ) {
        self.rhythmPlayer = rhythmPlayer
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

    func start(settings: RhythmMatchingSettings) {
        guard state == .idle else {
            logger.warning("start() called but state is \(String(describing: self.state)), not idle")
            return
        }

        self.settings = settings
        logger.info("Starting rhythm matching training loop")

        trainingTask = Task {
            await runTrainingLoop()
        }
    }

    func handleTap() {
        let actualTapTime = CACurrentMediaTime()

        guard state == .awaitingTap else {
            logger.warning("handleTap() called but state is \(String(describing: self.state))")
            return
        }
        guard let settings else {
            logger.error("handleTap() called but settings is nil")
            return
        }

        let offset = actualTapTime - expectedTapTime
        let userOffset = RhythmOffset(.seconds(offset))

        litDotCount = 4

        let completed = CompletedRhythmMatchingTrial(
            tempo: settings.tempo,
            expectedOffset: RhythmOffset(.zero),
            userOffset: userOffset
        )

        lastCompletedTrial = completed
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
        lastCompletedTrial = nil
        currentHandle = nil
        settings = nil
        expectedTapTime = 0

        showFeedback = false
        litDotCount = 0
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

        let pattern = buildPattern(settings: settings)

        do {
            state = .playingLeadIn
            litDotCount = 0
            let handle = try await rhythmPlayer.play(pattern)
            currentHandle = handle

            guard state != .idle && !Task.isCancelled else {
                logger.info("Training stopped during pattern playback, aborting")
                return
            }

            let sixteenthDuration = settings.tempo.sixteenthNoteDuration

            // Animate dots 1, 2, 3 at sixteenth-note intervals during lead-in
            for i in 0..<3 {
                guard state != .idle && !Task.isCancelled else { return }
                litDotCount = i + 1
                try await Task.sleep(for: sixteenthDuration)
            }

            guard state != .idle && !Task.isCancelled else {
                logger.info("Training stopped after lead-in, aborting")
                return
            }

            // The 4th beat should fall now — record expected tap time
            expectedTapTime = CACurrentMediaTime()
            state = .awaitingTap
            logger.info("Lead-in finished, awaiting tap")
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

    private func buildPattern(settings: RhythmMatchingSettings) -> RhythmPattern {
        let sixteenthDuration = settings.tempo.sixteenthNoteDuration
        let samplesPerSixteenth = Int64(sampleRate.rawValue * sixteenthDuration.timeInterval)
        let clickNote = MIDINote(76)
        let velocity = MIDIVelocity(100)

        let events = (0..<3).map { i in
            RhythmPattern.Event(
                sampleOffset: Int64(i) * samplesPerSixteenth,
                midiNote: clickNote,
                velocity: velocity
            )
        }
        return RhythmPattern(
            events: events,
            sampleRate: sampleRate,
            totalDuration: sixteenthDuration * 3
        )
    }

    private func transitionToFeedback(settings: RhythmMatchingSettings) {
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

    private func recordTrial(_ completed: CompletedRhythmMatchingTrial) {
        observers.forEach { observer in
            observer.rhythmMatchingCompleted(completed)
        }
    }
}
