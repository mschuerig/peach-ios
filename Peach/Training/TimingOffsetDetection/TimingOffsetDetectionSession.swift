import Foundation
import Observation
import QuartzCore
import os

enum TimingOffsetDetectionSessionState {
    case idle
    case playingPatternLoop
    case awaitingAnswer
    case showingFeedback
    case waitingForGrid
}

@Observable
final class TimingOffsetDetectionSession: TrainingSession, BeatProvider {

    // MARK: - State Machine Types

    enum Event {
        case startRequested
        case answerReceived(direction: TimingDirection)
        case feedbackTimerFired
        case gridAlignmentReached
        case repetitionCapReached
        case stopRequested
        case audioError
    }

    enum Effect {
        case beginNextTrial
        case stopSequencer
        case stopSequencerAtCap
        case evaluateAnswer(direction: TimingDirection)
        case scheduleFeedbackTimer
        case stopAll
    }

    /// Pure state transition function.
    static func reduce(state: inout TimingOffsetDetectionSessionState, event: Event) -> [Effect] {
        switch (state, event) {
        case (.idle, .startRequested):
            state = .playingPatternLoop
            return [.beginNextTrial]

        case (.playingPatternLoop, .answerReceived(let direction)),
             (.awaitingAnswer, .answerReceived(let direction)):
            state = .showingFeedback
            // Mechanism (.stopSequencer) is emitted ahead of policy (.evaluateAnswer)
            // so audio silencing is ordered explicitly rather than buried inside the
            // result-computation effect. From `.awaitingAnswer` the sequencer is
            // already stopped, but emitting `.stopSequencer` again is safe — the
            // chained `enqueueSequencerStop` serializes back-to-back stops.
            return [.stopSequencer, .evaluateAnswer(direction: direction), .scheduleFeedbackTimer]

        case (.showingFeedback, .feedbackTimerFired):
            state = .waitingForGrid
            return []

        case (.waitingForGrid, .gridAlignmentReached):
            state = .playingPatternLoop
            return [.beginNextTrial]

        case (.playingPatternLoop, .repetitionCapReached):
            // Cap exits the audio-playing phase into a silent awaiting-answer phase.
            // The state transition is the idempotence latch: subsequent polls in the
            // same trial see `state != .playingPatternLoop` and the cap check is gated.
            state = .awaitingAnswer
            return [.stopSequencerAtCap]

        case (.idle, .stopRequested):
            return []

        case (.idle, .audioError):
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

    // MARK: - Constants

    /// Index of the note that receives the timing offset (0-based among 4 sixteenth notes).
    /// The help text in TimingOffsetDetectionScreen refers to this position by ordinal name ("third").
    static let testedNoteIndex = 2

    /// 4 sixteenths per beat. Internal (not private) so tests can compute subdivision-aligned sample positions.
    static let subdivisionsPerBeat: Int = 4

    /// Sub-perceptual UI poll cadence (~125 Hz) that keeps `litDotCount` visually in lockstep with the audio.
    private static let trackingPollingInterval: Duration = .milliseconds(8)

    /// All-rest fallback returned by `nextBeat()` when no trial is active.
    /// A sequencer refill scheduled before `stop()` may still call `nextBeat()` after teardown;
    /// returning silence ensures no audible click pattern leaks past the session's lifetime.
    private static let silentBeat = Beat(subdivisions: Array(repeating: .rest, count: subdivisionsPerBeat))

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

    private let beatSequencer: any BeatSequencer
    private let strategy: NextTimingOffsetDetectionStrategy
    private let profile: TrainingProfile
    private let observers: [TimingOffsetDetectionObserver]
    private let currentTime: () -> Double
    private var lifecycle: SessionLifecycle?

    // MARK: - Training State

    private var settings: TimingOffsetDetectionSettings?
    private var currentTrial: TimingOffsetDetectionTrial?
    private var lastCompletedTrial: CompletedTimingOffsetDetectionTrial?
    private var gridOrigin: Double?
    private var startTask: Task<Void, Never>?
    private var trackingTask: Task<Void, Never>?
    /// Chained stop task — serializes back-to-back sequencer stops and waits out
    /// any in-flight `startTask` so concurrent start/stop can't race on the sequencer.
    private var stopTask: Task<Void, Never>?

    /// Last subdivision index published to `litDotCount`, gating Observation churn at the 120 Hz tracking rate.
    private var lastPublishedSubdivisionIndex: Int = -1

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
        beatSequencer: any BeatSequencer,
        strategy: NextTimingOffsetDetectionStrategy,
        profile: TrainingProfile,
        observers: [TimingOffsetDetectionObserver] = [],
        notificationCenter: NotificationCenter = .default,
        audioInterruptionObserver: AudioInterruptionObserving,
        backgroundNotificationName: Notification.Name? = nil,
        foregroundNotificationName: Notification.Name? = nil,
        currentTime: @escaping () -> Double = { CACurrentMediaTime() }
    ) {
        self.beatSequencer = beatSequencer
        self.strategy = strategy
        self.profile = profile
        self.observers = observers
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

    var canAcceptAnswer: Bool { state == .playingPatternLoop || state == .awaitingAnswer }

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
        guard state == .idle else {
            logger.warning("start() called but state is \(String(describing: self.state)), not idle")
            return
        }
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

    // MARK: - BeatProvider Protocol

    func nextBeat() -> Beat {
        guard let trial = currentTrial else { return Self.silentBeat }
        return Self.buildBeat(for: trial)
    }

    static func buildBeat(for trial: TimingOffsetDetectionTrial) -> Beat {
        let subdivisions: [Subdivision] = (0..<subdivisionsPerBeat).map { index in
            let velocity = (index == 0) ? RhythmVelocity.accent : RhythmVelocity.normal
            let offset: Duration = (index == testedNoteIndex) ? trial.offset.duration : .zero
            return .note(velocity: velocity, offset: offset)
        }
        return Beat(subdivisions: subdivisions)
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

        case .stopSequencer:
            stopSequencerForAnswer()

        case .stopSequencerAtCap:
            stopSequencerAtCap()

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
            let origin = currentTime()
            gridOrigin = origin
            logger.info("Grid origin established at \(origin)")
        }

        let trial = strategy.nextTimingOffsetDetectionTrial(
            profile: profile,
            settings: settings,
            lastResult: lastCompletedTrial
        )
        currentTrial = trial
        resetTracking()

        startTask = Task {
            do {
                try await beatSequencer.start(tempo: settings.tempo, beatProvider: self)
                guard state == .playingPatternLoop, !Task.isCancelled else {
                    logger.info("State changed while starting sequencer, aborting")
                    return
                }
                startTrackingLoop()
            } catch is CancellationError {
                logger.info("Sequencer start task cancelled")
            } catch {
                logger.error("Audio error, stopping training: \(error.localizedDescription)")
                send(.audioError)
            }
        }
    }

    private func startTrackingLoop() {
        trackingTask?.cancel()
        trackingTask = Task {
            while !Task.isCancelled {
                evaluatePlaybackPosition()
                try? await Task.sleep(for: Self.trackingPollingInterval)
            }
        }
    }

    /// Polls `beatSequencer.timing.samplePosition` and updates `litDotCount` on subdivision changes.
    /// Visible for testing.
    func evaluatePlaybackPosition() {
        let timing = beatSequencer.timing
        guard state == .playingPatternLoop,
              timing.samplePosition >= 0,
              timing.samplesPerBeat > 0 else { return }

        let samplesPerSubdivision = timing.samplesPerBeat / Int64(Self.subdivisionsPerBeat)
        guard samplesPerSubdivision > 0 else { return }

        let globalSubdivisionIndex = Int(timing.samplePosition / samplesPerSubdivision)

        // Cap-reached check runs *before* the `litDotCount` publish so the lit-dot
        // indicator does not flash one extra tick past the cap boundary. The
        // `.repetitionCapReached` event transitions the session out of
        // `.playingPatternLoop`, so the top-of-function state guard suppresses
        // any further polling-driven re-fires.
        let completedCycles = globalSubdivisionIndex / Self.subdivisionsPerBeat
        if let settings, completedCycles >= settings.maxRepetitions {
            send(.repetitionCapReached)
            return
        }

        if globalSubdivisionIndex != lastPublishedSubdivisionIndex {
            litDotCount = (globalSubdivisionIndex % Self.subdivisionsPerBeat) + 1
            lastPublishedSubdivisionIndex = globalSubdivisionIndex
        }
    }

    /// Cancels tracking and stops the sequencer in response to a user answer.
    private func stopSequencerForAnswer() {
        cancelTrackingAndReset()
        enqueueSequencerStop { [weak self] in self?.send(.audioError) }
    }

    /// Cancels tracking and stops the sequencer when the per-trial repetition cap is hit.
    /// Reducer has already transitioned the state to `.awaitingAnswer`; the trial completes
    /// via the normal `.answerReceived` path from that state. Failure is teardown-style
    /// (default no-op `onFailure`) to match `stopAll`: an `.audioError` escalation here
    /// would tear down the session before the user can answer.
    private func stopSequencerAtCap() {
        cancelTrackingAndReset()
        enqueueSequencerStop()
    }

    private func cancelTrackingAndReset() {
        trackingTask?.cancel()
        trackingTask = nil
        resetTracking()
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

        trackingTask?.cancel()
        trackingTask = nil
        lifecycle?.cancelAllTasks()

        // Teardown path uses the default no-op onFailure: an audio error here would re-enter
        // stopAll via the reducer (.audioError → .stopAll), looping. Logging-only is sufficient.
        enqueueSequencerStop()

        currentTrial = nil
        lastCompletedTrial = nil
        settings = nil
        gridOrigin = nil
        showFeedback = false
        isLastAnswerCorrect = nil
        resetTracking()
        sessionBestOffsetPercentage = nil
        sessionBestOffsetMs = nil
    }

    // MARK: - Private Helpers

    /// Serializes sequencer stops so an answer-driven stop followed by a teardown stop
    /// cannot race on the sequencer's internal `runLoopTask`. Each enqueued stop:
    /// awaits the previous stop, cancels-and-awaits any in-flight `startTask`, then calls
    /// `beatSequencer.stop()`. Non-cancellation errors are logged and forwarded to `onFailure`,
    /// which defaults to a no-op (suitable for teardown — errors logged and ignored) and is
    /// overridden by answer-driven stops to send `.audioError` per the spec's audio-error contract.
    private func enqueueSequencerStop(onFailure: @escaping () -> Void = {}) {
        let inflightStart = startTask
        startTask = nil
        let previousStop = stopTask
        stopTask = Task {
            await previousStop?.value
            if let inflightStart {
                inflightStart.cancel()
                await inflightStart.value
            }
            do {
                try await self.beatSequencer.stop()
            } catch is CancellationError {
                return
            } catch {
                self.logger.error("Failed to stop beat sequencer: \(error.localizedDescription)")
                onFailure()
            }
        }
    }

    private func resetTracking() {
        litDotCount = 0
        lastPublishedSubdivisionIndex = -1
    }

    private func nextGridPoint(quarterNoteDuration: Double) -> Double {
        guard let gridOrigin else { return currentTime() }
        let now = currentTime()
        let elapsed = now - gridOrigin
        let n = ceil(elapsed / quarterNoteDuration)
        return gridOrigin + n * quarterNoteDuration
    }
}
