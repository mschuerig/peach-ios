import Foundation
import Observation
import QuartzCore
import os

enum TimingOffsetDetectionSessionState {
    case idle
    case playingPattern
    case awaitingAnswer
    case showingFeedback
    case waitingForGrid
}

@Observable
final class TimingOffsetDetectionSession: TrainingSession {

    // MARK: - State Machine Types

    enum Event {
        case startRequested
        case patternFinished
        case answerReceived(direction: TimingDirection)
        case feedbackTimerFired
        case gridAlignmentReached
        case stopRequested
        case audioError
    }

    enum Effect {
        case beginNextTrial
        case evaluateAnswer(direction: TimingDirection)
        case scheduleFeedbackTimer
        case stopAll
    }

    /// Pure state transition function.
    static func reduce(state: inout TimingOffsetDetectionSessionState, event: Event) -> [Effect] {
        switch (state, event) {
        case (.idle, .startRequested):
            state = .playingPattern
            return [.beginNextTrial]

        case (.playingPattern, .patternFinished):
            state = .awaitingAnswer
            return []

        case (.awaitingAnswer, .answerReceived(let direction)):
            state = .showingFeedback
            return [.evaluateAnswer(direction: direction), .scheduleFeedbackTimer]

        case (.showingFeedback, .feedbackTimerFired):
            state = .waitingForGrid
            return []

        case (.waitingForGrid, .gridAlignmentReached):
            state = .playingPattern
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

    private let logger = Logger(subsystem: "com.peach.app", category: "TimingOffsetDetectionSession")

    // MARK: - Observable State

    private(set) var state: TimingOffsetDetectionSessionState = .idle
    private(set) var showFeedback: Bool = false
    private(set) var isLastAnswerCorrect: Bool? = nil
    private(set) var litDotCount: Int = 0
    private(set) var sessionBestOffsetPercentage: Double? = nil
    private(set) var sessionBestOffsetMs: Double? = nil

    // MARK: - Dependencies

    private let rhythmPlayer: RhythmPlayer
    private let strategy: NextTimingOffsetDetectionStrategy
    private let profile: TrainingProfile
    private let observers: [TimingOffsetDetectionObserver]
    private let sampleRate: SampleRate
    private let currentTime: () -> Double
    private var lifecycle: SessionLifecycle?

    // MARK: - Training State

    private var settings: TimingOffsetDetectionSettings?
    private var currentTrial: TimingOffsetDetectionTrial?
    private var lastCompletedTrial: CompletedTimingOffsetDetectionTrial?
    private var currentHandle: RhythmPlaybackHandle?
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
        strategy: NextTimingOffsetDetectionStrategy,
        profile: TrainingProfile,
        observers: [TimingOffsetDetectionObserver] = [],
        sampleRate: SampleRate,
        notificationCenter: NotificationCenter = .default,
        audioInterruptionObserver: AudioInterruptionObserving,
        backgroundNotificationName: Notification.Name? = nil,
        foregroundNotificationName: Notification.Name? = nil,
        currentTime: @escaping () -> Double = { CACurrentMediaTime() }
    ) {
        self.rhythmPlayer = rhythmPlayer
        self.strategy = strategy
        self.profile = profile
        self.observers = observers
        self.sampleRate = sampleRate
        self.currentTime = currentTime
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

    var canAcceptAnswer: Bool { state == .awaitingAnswer }

    /// Handles a letter-key shortcut by matching against localized Early/Late keys.
    /// Returns `true` if the key matched and the answer was accepted.
    @discardableResult
    func handleShortcutKey(_ character: String) -> Bool {
        let char = character.lowercased()
        let earlyKey = String(localized: "shortcut.early").lowercased()
        let lateKey = String(localized: "shortcut.late").lowercased()
        if char == earlyKey {
            return handleAnswer(direction: .early)
        } else if char == lateKey {
            return handleAnswer(direction: .late)
        }
        return false
    }

    func start(settings: TimingOffsetDetectionSettings) {
        self.settings = settings
        logger.info("Starting timing offset detection training loop")
        send(.startRequested)
    }

    @discardableResult
    func handleAnswer(direction: TimingDirection) -> Bool {
        logger.info("User answered: \(String(describing: direction))")
        let previousState = state
        send(.answerReceived(direction: direction))
        return state != previousState
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

        case .evaluateAnswer(let direction):
            evaluateAnswer(direction: direction)

        case .scheduleFeedbackTimer:
            scheduleFeedbackTimer()

        case .stopAll:
            stopAll()
        }
    }

    // MARK: - Effect Implementations

    private func beginNextTrial() {
        guard let settings else { return }

        if gridOrigin == nil {
            gridOrigin = currentTime()
            logger.info("Grid origin established at \(self.gridOrigin!)")
        }

        let trial = strategy.nextTimingOffsetDetectionTrial(
            profile: profile,
            settings: settings,
            lastResult: lastCompletedTrial
        )
        currentTrial = trial

        let pattern = buildPattern(for: trial, settings: settings)

        lifecycle?.setTrainingTask(Task {
            do {
                litDotCount = 0
                let handle = try await rhythmPlayer.play(pattern)
                currentHandle = handle

                guard state != .idle && !Task.isCancelled else {
                    logger.info("Training stopped during pattern playback, aborting")
                    return
                }

                let sixteenthDuration = settings.tempo.sixteenthNoteDuration
                for i in 0..<4 {
                    guard state != .idle && !Task.isCancelled else { return }
                    litDotCount = i + 1
                    if i < 3 {
                        try await Task.sleep(for: sixteenthDuration)
                    }
                }
                try await Task.sleep(for: sixteenthDuration)

                guard state != .idle && !Task.isCancelled else {
                    logger.info("Training stopped after pattern completed, aborting")
                    return
                }

                logger.info("Pattern finished, awaiting answer")
                send(.patternFinished)
            } catch is CancellationError {
                logger.info("Training task cancelled")
            } catch {
                logger.error("Audio error, stopping training: \(error.localizedDescription)")
                send(.audioError)
            }
        })
    }

    private func evaluateAnswer(direction: TimingDirection) {
        guard let trial = currentTrial else { return }

        let isCorrect = (direction == trial.offset.direction)

        let completed = CompletedTimingOffsetDetectionTrial(
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

        isLastAnswerCorrect = isCorrect
        showFeedback = true

        observers.forEach { observer in
            observer.timingOffsetDetectionCompleted(completed)
        }
    }

    private func scheduleFeedbackTimer() {
        guard let settings else { return }
        logger.info("Entering feedback state")

        lifecycle?.setFeedbackTask(Task {
            try? await Task.sleep(for: settings.feedbackDuration)
            guard state == .showingFeedback && !Task.isCancelled else { return }

            showFeedback = false
            send(.feedbackTimerFired)

            // Wait for grid alignment
            let quarterDuration = settings.tempo.quarterNoteDuration.timeInterval
            let gridPoint = nextGridPoint(quarterNoteDuration: quarterDuration)
            let now = currentTime()
            let waitTime = gridPoint - now

            if waitTime > 0 {
                litDotCount = 0
                logger.info("Waiting \(waitTime)s for grid alignment")
                try? await Task.sleep(for: .seconds(waitTime))
                guard state == .waitingForGrid && !Task.isCancelled else { return }
            }

            logger.info("Grid-aligned, starting next trial")
            send(.gridAlignmentReached)
        })
    }

    private func stopAll() {
        logger.info("Training stopped")

        Task {
            try? await currentHandle?.stop()
            try? await rhythmPlayer.stopAll()
        }

        lifecycle?.cancelAllTasks()

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

    // MARK: - Private Helpers

    private func nextGridPoint(quarterNoteDuration: Double) -> Double {
        guard let gridOrigin else { return currentTime() }
        let now = currentTime()
        let elapsed = now - gridOrigin
        let n = ceil(elapsed / quarterNoteDuration)
        return gridOrigin + n * quarterNoteDuration
    }

    /// Index of the note that receives the timing offset (0-based among 4 sixteenth notes).
    /// The help text in TimingOffsetDetectionScreen refers to this position by ordinal name ("third").
    static let testedNoteIndex = 2

    private static let patternNoteCount = 4

    private func buildPattern(for trial: TimingOffsetDetectionTrial, settings: TimingOffsetDetectionSettings) -> RhythmPattern {
        let sixteenthDuration = settings.tempo.sixteenthNoteDuration
        let samplesPerSixteenth = Int64(sampleRate.rawValue * sixteenthDuration.timeInterval)

        let clickNote = MIDINote(76)
        let offsetSamples = Int64(sampleRate.rawValue * trial.offset.duration.timeInterval)

        let events = (0..<Self.patternNoteCount).map { i in
            let base = Int64(i) * samplesPerSixteenth
            let offset = (i == Self.testedNoteIndex) ? offsetSamples : 0
            let velocity = (i == 0) ? StepVelocity.accent : StepVelocity.normal
            return RhythmPattern.Event(
                sampleOffset: base + offset,
                midiNote: clickNote,
                velocity: velocity
            )
        }

        return RhythmPattern(
            events: events,
            sampleRate: sampleRate,
            totalDuration: sixteenthDuration * 4
        )
    }
}
